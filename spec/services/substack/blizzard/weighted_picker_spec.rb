# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::WeightedPicker do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, url: 'https://sub/p/a', data: data }

  def entry(uid, body_json, notes)
    { 'uid' => uid, 'text' => uid, 'body_json' => body_json, 'notes' => notes }
  end

  # e0 postable, posted long ago; e1 has no body_json (unpostable).
  let(:data) do
    { 'blizzard' => [
      entry('e0', { 'type' => 'doc' }, [{ 'url' => 'u', 'timestamp' => 90.days.ago.iso8601, 'likes' => 5 }]),
      entry('e1', {}, [])
    ] }
  end

  before { BlizzardScheduleConfig.instance.update!(interval_minutes: 30, cooldown_hours: 12, last_reposted_at: nil) }

  subject(:pick) { described_class.execute }

  it { expect(pick['uid']).to eq 'e0' }
  it { expect(pick['body_json']).to eq({ 'type' => 'doc' }) }
  it { expect(pick['post_url']).to eq 'https://sub/p/a' }

  it 'claims by stamping last_reposted_at' do
    pick
    expect(BlizzardScheduleConfig.instance.last_reposted_at).to be_present
  end

  describe 'not yet due' do
    before { BlizzardScheduleConfig.instance.update!(last_reposted_at: 5.minutes.ago) }
    it { expect(pick).to be_nil }
  end

  describe 'past the interval is due again' do
    before { BlizzardScheduleConfig.instance.update!(last_reposted_at: 31.minutes.ago) }
    it { expect(pick).to_not be_nil }
  end

  describe 'dry_run picks without claiming' do
    subject(:pick) { described_class.execute(dry_run: true) }
    it { expect(pick['uid']).to eq 'e0' }
    it 'leaves last_reposted_at unchanged' do
      pick
      expect(BlizzardScheduleConfig.instance.last_reposted_at).to be_nil
    end
  end

  describe 'a post reposted within cooldown is excluded' do
    let(:data) { { 'blizzard' => [entry('e0', { 'type' => 'doc' }, [{ 'url' => 'u', 'timestamp' => 1.hour.ago.iso8601 }])] } }
    it { expect(pick).to be_nil }
  end

  describe 'a never-posted entry is eligible on base weight' do
    let(:data) { { 'blizzard' => [entry('e0', { 'type' => 'doc' }, [])] } }
    it { expect(pick['uid']).to eq 'e0' }
  end

  describe 'weighting favours the more-liked entry' do
    let(:data) do
      { 'blizzard' => [
        entry('e0', { 'type' => 'doc' }, [{ 'url' => 'u',  'timestamp' => 90.days.ago.iso8601, 'likes' => 5 }]),
        entry('e9', { 'type' => 'doc' }, [{ 'url' => 'u2', 'timestamp' => 90.days.ago.iso8601, 'likes' => 100 }])
      ] }
    end

    # cumulative order [e0 (weight 6), e9 (weight 101)] over a total of 107.
    it { expect(described_class.execute(random: double(rand: 3))['uid']).to eq 'e0' }
    it { expect(described_class.execute(random: double(rand: 50))['uid']).to eq 'e9' }
  end

  describe 'nothing eligible' do
    let(:data) { { 'blizzard' => [entry('e1', {}, [])] } }
    it { expect(pick).to be_nil }
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::RepostOdds do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site, title: 'A Post' }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, url: 'https://sub/p/a', data: data }

  def entry(uid, body_json, notes)
    { 'uid' => uid, 'text' => "text-#{uid}", 'body_json' => body_json, 'notes' => notes }
  end

  let(:data) do
    { 'blizzard' => [
      entry('e0',       { 'type' => 'doc' }, [{ 'url' => 'u',  'timestamp' => 90.days.ago.iso8601, 'likes' => 4 }]),
      entry('e9',       { 'type' => 'doc' }, [{ 'url' => 'u2', 'timestamp' => 90.days.ago.iso8601, 'likes' => 95 }]),
      entry('nobody',   {},                  []),
      entry('cooldown', { 'type' => 'doc' }, [{ 'url' => 'u3', 'timestamp' => 1.hour.ago.iso8601 }])
    ] }
  end

  before { BlizzardScheduleConfig.instance.update!(cooldown_hours: 12) }

  subject(:odds) { described_class.execute }

  def candidate(uid)
    odds.find { |c| c.entry['uid'] == uid }
  end

  it 'includes only postable, off-cooldown entries' do
    expect(odds.map { |c| c.entry['uid'] }).to contain_exactly('e0', 'e9')
  end

  describe 'weight is 1 + sum of note likes' do
    it { expect(candidate('e0').weight).to eq 5 }
    it { expect(candidate('e9').weight).to eq 96 }
  end

  describe 'the post likes are folded into every one of its entries' do
    before { post.update_column(:substack_likes, 10) }

    it { expect(candidate('e0').weight).to eq 15 } # 1 + 4 note + 10 post
    it { expect(candidate('e9').weight).to eq 106 } # 1 + 95 note + 10 post
    it { expect(candidate('e0').likes).to eq 14 }   # displayed total: note + post
  end

  describe 'probability is weight / total' do
    it { expect(candidate('e9').probability).to be_within(0.0001).of(96.0 / 101) }
    it { expect(odds.sum(&:probability)).to be_within(0.0001).of(1.0) }
  end

  describe 'Candidate helpers' do
    it { expect(candidate('e0').title).to eq 'A Post' }
    it { expect(candidate('e0').likes).to eq 4 }
    it { expect(candidate('e0').text).to eq 'text-e0' }
  end
end

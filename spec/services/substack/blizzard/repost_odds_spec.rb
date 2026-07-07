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

  # Post A: off cooldown (its most recent note is 90 days old).
  let(:data) do
    { 'blizzard' => [
      entry('e0',     { 'type' => 'doc' }, [{ 'url' => 'u',  'timestamp' => 90.days.ago.iso8601, 'likes' => 4 }]),
      entry('e9',     { 'type' => 'doc' }, [{ 'url' => 'u2', 'timestamp' => 90.days.ago.iso8601, 'likes' => 95 }]),
      entry('nobody', {},                  [])
    ] }
  end

  before { BlizzardScheduleConfig.instance.update!(cooldown_hours: 12) }

  subject(:odds) { described_class.execute }

  def candidate(uid)
    odds.find { |c| c.entry['uid'] == uid }
  end

  it 'includes only postable entries on off-cooldown posts' do
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

  describe 'per-post cooldown' do
    let!(:post_b) { create :post, site: site, title: 'B Post', slug: 'b' }
    let!(:cat_b) do
      create :categorization, category: category, categorized: post_b, url: 'https://sub/p/b', data: { 'blizzard' => [
        entry('fresh', { 'type' => 'doc' }, [{ 'url' => 'r', 'timestamp' => 1.hour.ago.iso8601 }]),
        entry('stale', { 'type' => 'doc' }, [{ 'url' => 's', 'timestamp' => 90.days.ago.iso8601 }])
      ] }
    end

    it 'benches every entry of a post reposted within cooldown, even its stale ones' do
      expect(odds.map { |c| c.entry['uid'] } & %w[fresh stale]).to be_empty
    end

    it 'still includes entries of off-cooldown posts' do
      expect(odds.map { |c| c.entry['uid'] }).to include('e0', 'e9')
    end
  end
end

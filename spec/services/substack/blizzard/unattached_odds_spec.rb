# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::UnattachedOdds do

  def entry(uid, body_json, notes)
    { 'uid' => uid, 'text' => "text-#{uid}", 'body_json' => body_json, 'notes' => notes }
  end

  # e0/e9 off cooldown (90 days old); nobody has no body_json.
  let(:data) do
    { 'blizzard' => [
      entry('e0',     { 'type' => 'doc' }, [{ 'url' => 'u',  'timestamp' => 90.days.ago.iso8601, 'likes' => 4 }]),
      entry('e9',     { 'type' => 'doc' }, [{ 'url' => 'u2', 'timestamp' => 90.days.ago.iso8601, 'likes' => 95 }]),
      entry('nobody', {},                  [])
    ] }
  end

  before { BlizzardScheduleConfig.instance.update!(cooldown_hours: 12, data: data) }

  subject(:odds) { described_class.execute }

  def candidate(uid)
    odds.find { |c| c.entry['uid'] == uid }
  end

  it 'includes only postable, off-cooldown entries' do
    expect(odds.map { |c| c.entry['uid'] }).to contain_exactly('e0', 'e9')
  end

  describe 'weight is 1 + sum of note likes (no post-likes term)' do
    it { expect(candidate('e0').weight).to eq 5 }
    it { expect(candidate('e9').weight).to eq 96 }
    it { expect(candidate('e0').likes).to eq 4 }
  end

  describe 'probability is weight / total' do
    it { expect(candidate('e9').probability).to be_within(0.0001).of(96.0 / 101) }
    it { expect(odds.sum(&:probability)).to be_within(0.0001).of(1.0) }
  end

  describe 'Candidate helpers' do
    it { expect(candidate('e0').text).to eq 'text-e0' }
    it { expect(candidate('e0').uid).to eq 'e0' }
  end

  describe 'per-entry cooldown (no post to bench as a group)' do
    let(:data) do
      { 'blizzard' => [
        entry('fresh', { 'type' => 'doc' }, [{ 'url' => 'r', 'timestamp' => 1.hour.ago.iso8601 }]),
        entry('stale', { 'type' => 'doc' }, [{ 'url' => 's', 'timestamp' => 90.days.ago.iso8601 }])
      ] }
    end

    it 'benches only the recently-reposted entry, not the whole pool' do
      expect(odds.map { |c| c.entry['uid'] }).to eq ['stale']
    end
  end

  describe 'empty pool' do
    let(:data) { {} }

    it { expect(odds).to eq [] }
  end
end

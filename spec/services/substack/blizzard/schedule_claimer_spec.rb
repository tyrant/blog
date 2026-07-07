# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::ScheduleClaimer do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, url: 'https://sub/p/a', data: data }

  def entry(text, body_json)
    { 'uid' => text, 'text' => text, 'body_json' => body_json, 'notes' => [{ 'url' => 'u', 'timestamp' => 90.days.ago.iso8601 }] }
  end

  # g0 postable; g1 has blank body_json.
  let(:data) { { 'blizzard' => [entry('g0', { 'type' => 'doc' }), entry('g1', {})] } }

  def ev(uid, t, extra = {})
    { 'c' => categorization.id, 'u' => uid, 't' => t }.merge(extra)
  end

  def set_schedule(events)
    BlizzardScheduleConfig.instance.update!(schedule: { 'events' => events })
  end

  def stored_events
    BlizzardScheduleConfig.instance.schedule['events']
  end

  describe 'due selection' do
    before { set_schedule([ev('g0', 1.hour.ago.utc.iso8601), ev('g0', 5.days.from_now.utc.iso8601)]) }
    subject(:claimed) { described_class.execute }

    it { expect(claimed.size).to eq 1 }
    it { expect(claimed.first['body_json']).to eq({ 'type' => 'doc' }) }

    describe 'claim marking' do
      before { described_class.execute }
      it { expect(stored_events.first['claimed_at']).to be_present }
      it { expect(stored_events.last['claimed_at']).to be_nil }
    end
  end

  describe 'skips already-posted events' do
    before { set_schedule([ev('g0', 1.hour.ago.utc.iso8601, 'posted_at' => 1.minute.ago.utc.iso8601)]) }
    it { expect(described_class.execute).to be_empty }
  end

  describe 'a freshly-claimed event' do
    before { set_schedule([ev('g0', 1.hour.ago.utc.iso8601, 'claimed_at' => 1.minute.ago.utc.iso8601)]) }
    it { expect(described_class.execute).to be_empty }
  end

  describe 'a stale claim (older than the timeout) is reclaimed' do
    before { set_schedule([ev('g0', 1.hour.ago.utc.iso8601, 'claimed_at' => 2.hours.ago.utc.iso8601)]) }
    it { expect(described_class.execute.size).to eq 1 }
  end

  describe 'skips groups with no body_json' do
    before { set_schedule([ev('g1', 1.hour.ago.utc.iso8601)]) }
    it { expect(described_class.execute).to be_empty }
  end

  describe 'skips orphaned group uids' do
    before { set_schedule([ev('missing', 1.hour.ago.utc.iso8601)]) }
    it { expect(described_class.execute).to be_empty }
  end

  describe 'respects the limit, oldest-first' do
    before do
      set_schedule([ev('g0', 3.hours.ago.utc.iso8601), ev('g0', 1.hour.ago.utc.iso8601), ev('g0', 2.hours.ago.utc.iso8601)])
    end
    it { expect(described_class.execute(limit: 2).size).to eq 2 }

    describe 'only two get claimed' do
      before { described_class.execute(limit: 2) }
      it { expect(stored_events.count { |e| e['claimed_at'] }).to eq 2 }
    end
  end

  describe 'dry_run returns due events without claiming' do
    before { set_schedule([ev('g0', 1.hour.ago.utc.iso8601)]) }
    it { expect(described_class.execute(dry_run: true).size).to eq 1 }

    describe 'no claim written' do
      before { described_class.execute(dry_run: true) }
      it { expect(stored_events.first['claimed_at']).to be_nil }
    end
  end
end

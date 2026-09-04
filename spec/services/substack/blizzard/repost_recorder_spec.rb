# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::RepostRecorder do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, data: data }

  let(:data) { { 'blizzard' => [{ 'uid' => 'e0', 'text' => 'g0', 'body_json' => { 'type' => 'doc' }, 'notes' => [] }] } }
  let(:url) { 'https://substack.com/@m/note/c-9' }

  def record(u = url)
    described_class.execute(categorization_id: categorization.id, uid: 'e0', url: u, timestamp: '2026-07-04T00:00:00Z')
  end

  it 'appends the note seeded with zero likes' do
    record
    note = categorization.reload.data['blizzard'][0]['notes'].last
    expect(note).to include('url' => url, 'timestamp' => '2026-07-04T00:00:00Z', 'likes' => 0)
  end

  it 'is idempotent by url' do
    record
    record
    expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 1
  end

  context 'unknown uid' do
    before { described_class.execute(categorization_id: categorization.id, uid: 'nope', url: url, timestamp: '2026-07-04T00:00:00Z') }
    it { expect(categorization.reload.data['blizzard'][0]['notes']).to be_empty }
  end

  context 'a blank categorization_id (the unattached-notes pool)' do
    let!(:config) do
      BlizzardScheduleConfig.instance.tap do |c|
        c.update!(data: { 'blizzard' => [{ 'uid' => 'u0', 'text' => 'g0', 'body_json' => { 'type' => 'doc' }, 'notes' => [] }] })
      end
    end

    def record(u = url)
      described_class.execute(categorization_id: nil, uid: 'u0', url: u, timestamp: '2026-07-04T00:00:00Z')
    end

    it 'appends the note to BlizzardScheduleConfig instead of a categorization' do
      record
      note = config.reload.data['blizzard'][0]['notes'].last
      expect(note).to include('url' => url, 'timestamp' => '2026-07-04T00:00:00Z', 'likes' => 0)
    end

    it 'leaves the categorization untouched' do
      record
      expect(categorization.reload.data['blizzard'][0]['notes']).to be_empty
    end
  end
end

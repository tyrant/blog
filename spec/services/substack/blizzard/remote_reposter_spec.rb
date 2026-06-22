# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::RemoteReposter do

  let(:base_url) { 'https://prod.example.com' }
  let(:commit) { true }

  let(:groups) do
    [{ 'categorization_id' => 7, 'index' => 0, 'text' => 'hello',
       'body_json' => { 'type' => 'doc' },
       'template_url' => 'https://substack.com/profile/4619740-mikey-clarke/note/c-111' }]
  end

  subject(:result) do
    described_class.execute(base_url: base_url, username: 'u', password: 'p', days: 30, commit: commit)
  end

  before do
    SubstackSyncConfig.instance.update!(session_cookie: 'sess')
    allow_any_instance_of(described_class).to receive(:sleep)

    stub_request(:get, "#{base_url}/admin/substack-blizzard/due.json?days=30")
      .to_return(status: 200, body: groups.to_json)
    stub_request(:post, 'https://substack.com/api/v1/comment/feed')
      .to_return(status: 200, body: { 'id' => 999, 'date' => '2026-06-22T00:00:00Z' }.to_json)
  end

  context 'commit' do
    let!(:add_note) do
      stub_request(:post, "#{base_url}/admin/substack-blizzard/add-note.json")
        .to_return(status: 200, body: { 'success' => true }.to_json)
    end

    it { expect(result.posted.size).to eq 1 }
    it { expect(result.posted.first['url']).to eq 'https://substack.com/profile/4619740-mikey-clarke/note/c-999' }
    it { expect(result.posted.first['timestamp']).to eq '2026-06-22T00:00:00Z' }

    it 'creates the note from the group body_json' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/feed')
        .with(body: hash_including('bodyJson' => { 'type' => 'doc' }))).to have_been_made
    end

    it 'records the new note back on prod' do
      result
      expect(add_note.with(body: hash_including('categorization_id' => '7', 'index' => '0'))).to have_been_requested
    end
  end

  context 'limit' do
    let(:groups) { Array.new(3) { |n| { 'categorization_id' => n, 'index' => 0, 'text' => "g#{n}", 'body_json' => {}, 'template_url' => nil } } }
    subject(:result) { described_class.execute(base_url: base_url, username: 'u', password: 'p', days: 30, limit: 1, commit: false) }

    it { expect(result.posted.size).to eq 1 }
  end

  context 'dry run' do
    let(:commit) { false }

    it { expect(result.posted.first['dry_run']).to be true }
    it 'creates no notes' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/feed')).to_not have_been_made
    end
  end
end

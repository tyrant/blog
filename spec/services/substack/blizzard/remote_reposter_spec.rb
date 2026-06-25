# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::RemoteReposter do

  let(:base_url) { 'https://prod.example.com' }
  let(:commit) { true }

  let(:post_url) { 'https://mikeyclarke.substack.com/p/foo' }
  let(:groups) do
    [{ 'categorization_id' => 7, 'index' => 0, 'text' => 'hello', 'post_url' => post_url,
       'body_json' => { 'type' => 'doc', 'content' => [
         { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'hello' }] },
         { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => post_url, 'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => post_url } }] }] }
       ] },
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
    stub_request(:post, 'https://substack.com/api/v1/comment/attachment')
      .to_return(status: 200, body: { 'id' => 'att-1' }.to_json)
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

    it 'creates a link attachment for the post URL' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/attachment')
        .with(body: hash_including('url' => post_url, 'type' => 'link'))).to have_been_made
    end

    it 'posts the body with the inline URL stripped and the attachment referenced' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/feed').with { |req|
        payload = JSON.parse(req.body)
        payload['attachmentIds'] == ['att-1'] && payload['bodyJson']['content'].size == 1
      }).to have_been_made
    end

    it 'records the new note back on prod' do
      result
      expect(add_note.with(body: hash_including('categorization_id' => '7', 'index' => '0'))).to have_been_requested
    end
  end

  context 'limit caps posts, not skipped rows' do
    # First group is skip-worthy (no body_json); limit 1 should still yield 1 postable.
    let(:groups) do
      [{ 'categorization_id' => 0, 'index' => 0, 'text' => 'empty', 'body_json' => nil, 'template_url' => nil },
       { 'categorization_id' => 1, 'index' => 0, 'text' => 'g1', 'body_json' => { 'type' => 'doc' }, 'template_url' => nil },
       { 'categorization_id' => 2, 'index' => 0, 'text' => 'g2', 'body_json' => { 'type' => 'doc' }, 'template_url' => nil }]
    end
    subject(:result) { described_class.execute(base_url: base_url, username: 'u', password: 'p', days: 30, limit: 1, commit: false) }

    it { expect(result.posted.map { |p| p['text'] }).to eq ['g1'] }
    it { expect(result.skipped.size).to eq 1 }
  end

  context 'group without body_json is skipped, not posted' do
    let(:groups) { [{ 'categorization_id' => 7, 'index' => 0, 'text' => 'empty', 'body_json' => nil, 'template_url' => nil }] }

    it { expect(result.skipped.map { |s| s['reason'] }).to eq ['no body_json'] }
    it { expect(result.posted).to be_empty }
    it 'creates no note' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/feed')).to_not have_been_made
    end
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

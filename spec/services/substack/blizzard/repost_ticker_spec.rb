# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::RepostTicker do

  let(:base_url) { 'https://prod.example.com' }
  let(:commit) { true }
  let(:post_url) { 'https://mikeyclarke.substack.com/p/foo' }

  let(:group) do
    { 'categorization_id' => 7, 'uid' => 'e0', 't' => nil, 'text' => 'hello', 'post_url' => post_url,
      'body_json' => { 'type' => 'doc', 'content' => [
        { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'hello' }] },
        { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => post_url, 'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => post_url } }] }] }
      ] },
      'template_url' => 'https://substack.com/profile/4619740-mikey-clarke/note/c-111' }
  end

  subject(:result) { described_class.execute(base_url: base_url, username: 'u', password: 'p', commit: commit) }

  before do
    SubstackSyncConfig.instance.update!(session_cookie: 'sess')

    stub_request(:post, "#{base_url}/admin/substack-blizzard/repost/tick.json").to_return(status: 200, body: group.to_json)
    stub_request(:get, "#{base_url}/admin/substack-blizzard/repost/preview.json").to_return(status: 200, body: group.to_json)
    stub_request(:post, 'https://substack.com/api/v1/comment/attachment').to_return(status: 200, body: { 'id' => 'att-1' }.to_json)
    stub_request(:post, 'https://substack.com/api/v1/comment/feed').to_return(status: 200, body: { 'id' => 999, 'date' => '2026-06-22T00:00:00Z' }.to_json)
  end

  context 'commit' do
    let!(:confirm) do
      stub_request(:post, "#{base_url}/admin/substack-blizzard/repost/confirm.json").to_return(status: 200, body: { ok: true }.to_json)
    end

    it { expect(result.posted.size).to eq 1 }
    it { expect(result.posted.first['url']).to eq 'https://substack.com/profile/4619740-mikey-clarke/note/c-999' }

    it 'creates a link attachment for the post URL' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/attachment')
        .with(body: hash_including('url' => post_url, 'type' => 'link'))).to have_been_made
    end

    it 'confirms back on prod with the entry identity' do
      result
      expect(confirm.with(body: hash_including('categorization_id' => '7', 'uid' => 'e0'))).to have_been_requested
    end
  end

  context 'an empty tick (nothing to repost)' do
    before { stub_request(:post, "#{base_url}/admin/substack-blizzard/repost/tick.json").to_return(status: 200, body: '{}') }

    it { expect(result.posted).to be_empty }

    it 'creates no note' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/feed')).to_not have_been_made
    end
  end

  context 'dry run' do
    let(:commit) { false }

    it { expect(result.posted.first['dry_run']).to be true }

    it 'does not claim' do
      result
      expect(a_request(:post, "#{base_url}/admin/substack-blizzard/repost/tick.json")).to_not have_been_made
    end
  end

  context 'a quotation repost (no entry to confirm)' do
    before do
      stub_request(:post, "#{base_url}/admin/substack-blizzard/repost/tick.json")
        .to_return(status: 200, body: group.merge('categorization_id' => nil, 'uid' => nil, 'template_url' => nil).to_json)
    end

    let!(:confirm) do
      stub_request(:post, "#{base_url}/admin/substack-blizzard/repost/confirm.json").to_return(status: 200, body: { ok: true }.to_json)
    end

    it { expect(result.posted.size).to eq 1 }

    it 'posts the note' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/feed')).to have_been_made
    end

    it 'skips the confirm step' do
      result
      expect(confirm).to_not have_been_requested
    end
  end

  context 'a group with no body_json' do
    before do
      stub_request(:post, "#{base_url}/admin/substack-blizzard/repost/tick.json")
        .to_return(status: 200, body: { 'categorization_id' => 1, 'uid' => 'e0', 'text' => 'empty', 'body_json' => nil, 'template_url' => nil }.to_json)
    end

    it { expect(result.skipped.size).to eq 1 }
    it { expect(result.posted).to be_empty }
  end
end

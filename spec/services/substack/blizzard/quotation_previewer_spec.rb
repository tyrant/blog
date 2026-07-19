# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::QuotationPreviewer do

  let(:base_url) { 'https://prod.example.com' }
  let(:id) { nil }
  let(:post_url) { 'https://mikeyclarke.substack.com/p/foo' }

  let(:group) do
    { 'text' => 'a lovely blurb', 'post_url' => post_url,
      'body_json' => { 'type' => 'doc', 'content' => [
        { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Review:' }] },
        { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => post_url, 'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => post_url } }] }] }
      ] } }
  end

  subject(:result) { described_class.execute(base_url: base_url, username: 'u', password: 'p', id: id) }

  before do
    SubstackSyncConfig.instance.update!(session_cookie: 'sess')

    stub_request(:get, "#{base_url}/admin/substack-blizzard/quotation/preview.json").to_return(status: 200, body: group.to_json)
    stub_request(:post, 'https://substack.com/api/v1/comment/attachment').to_return(status: 200, body: { 'id' => 'att-1' }.to_json)
    stub_request(:post, 'https://substack.com/api/v1/comment/feed').to_return(status: 200, body: { 'id' => 999 }.to_json)
  end

  it { expect(result['id']).to eq 999 }
  it { expect(result['url']).to eq 'https://substack.com/note/c-999' }
  it { expect(result['text']).to eq 'a lovely blurb' }

  it 'creates a link attachment for the post URL' do
    result
    expect(a_request(:post, 'https://substack.com/api/v1/comment/attachment')
      .with(body: hash_including('url' => post_url, 'type' => 'link'))).to have_been_made
  end

  it 'strips the trailing post-url paragraph before posting (it rides as the card)' do
    result
    expect(a_request(:post, 'https://substack.com/api/v1/comment/feed')
      .with { |req| JSON.parse(req.body)['bodyJson']['content'].size == 1 }).to have_been_made
  end

  context 'with an explicit id' do
    let(:id) { 42 }
    before { stub_request(:get, "#{base_url}/admin/substack-blizzard/quotation/preview.json?id=42").to_return(status: 200, body: group.to_json) }

    it 'requests that quotation' do
      result
      expect(a_request(:get, "#{base_url}/admin/substack-blizzard/quotation/preview.json?id=42")).to have_been_made
    end
  end

  context 'when prod has no quotations' do
    before { stub_request(:get, "#{base_url}/admin/substack-blizzard/quotation/preview.json").to_return(status: 200, body: '{}') }

    it { expect(result).to be_nil }

    it 'posts no note' do
      result
      expect(a_request(:post, 'https://substack.com/api/v1/comment/feed')).to_not have_been_made
    end
  end
end

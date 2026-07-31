# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bluesky::Client do
  subject(:client) { described_class.new(handle: handle, app_password: password, host: 'https://bsky.social') }

  let(:handle) { 'me.bsky.social' }
  let(:password) { 'app-pw-1234' }
  let(:record) { { '$type' => 'app.bsky.feed.post', 'text' => 'hi' } }

  def stub_session(status: 200)
    stub_request(:post, 'https://bsky.social/xrpc/com.atproto.server.createSession')
      .with(body: { identifier: handle, password: password }.to_json)
      .to_return(status: status, body: { accessJwt: 'jwt-abc', did: 'did:plc:xyz' }.to_json)
  end

  describe '#create_post' do
    let!(:session) { stub_session }
    let!(:create) do
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.createRecord')
        .with(headers: { 'Authorization' => 'Bearer jwt-abc' },
              body: hash_including('repo' => 'did:plc:xyz', 'collection' => 'app.bsky.feed.post', 'record' => record))
        .to_return(status: 200, body: { uri: 'at://did:plc:xyz/app.bsky.feed.post/rk1', cid: 'cid1' }.to_json)
    end

    it { expect(client.create_post(record)).to eq('uri' => 'at://did:plc:xyz/app.bsky.feed.post/rk1', 'cid' => 'cid1') }

    it 'authenticates with the app password first' do
      client.create_post(record)
      expect(session).to have_been_requested
    end

    it 'sends the record under the account repo with the bearer token' do
      client.create_post(record)
      expect(create).to have_been_requested
    end

    it 'authenticates only once across the call' do
      client.create_post(record)
      expect(session).to have_been_requested.once
    end
  end

  describe '#upload_blob' do
    let!(:session) { stub_session }
    let!(:upload) do
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.uploadBlob')
        .with(headers: { 'Authorization' => 'Bearer jwt-abc', 'Content-Type' => 'image/jpeg' }, body: 'rawbytes')
        .to_return(status: 200, body: { blob: { '$type' => 'blob', 'ref' => { '$link' => 'bafk1' } } }.to_json)
    end

    it { expect(client.upload_blob('rawbytes', 'image/jpeg')).to eq('$type' => 'blob', 'ref' => { '$link' => 'bafk1' }) }

    it 'posts the raw bytes with the image content type' do
      client.upload_blob('rawbytes', 'image/jpeg')
      expect(upload).to have_been_requested
    end
  end

  describe 'missing credentials' do
    let(:password) { nil }

    it { expect { client.create_post(record) }.to raise_error(Bluesky::Client::AuthError, /No Bluesky credentials/) }
  end

  describe 'auth rejection' do
    before { stub_session(status: 401) }

    it { expect { client.create_post(record) }.to raise_error(Bluesky::Client::AuthError, /rejected the app password/) }
  end

  describe 'rate limiting' do
    before do
      allow_any_instance_of(described_class).to receive(:backoff_sleep)
      stub_session
    end

    context 'retries after a 429 then succeeds' do
      before do
        stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.createRecord')
          .to_return({ status: 429, headers: { 'Retry-After' => '0' } },
                     { status: 200, body: { uri: 'at://x/rk', cid: 'c' }.to_json })
      end

      it { expect(client.create_post(record)).to eq('uri' => 'at://x/rk', 'cid' => 'c') }
    end

    context 'gives up after persistent 429' do
      before { stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.createRecord').to_return(status: 429, body: 'slow down') }

      it { expect { client.create_post(record) }.to raise_error(Bluesky::Client::Error, /429/) }
    end
  end

  describe 'server error' do
    before do
      stub_session
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.createRecord').to_return(status: 500, body: 'boom')
    end

    it { expect { client.create_post(record) }.to raise_error(Bluesky::Client::Error, /500/) }
  end
end

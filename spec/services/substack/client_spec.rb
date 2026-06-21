# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Client do

  subject(:client) { described_class.new(session_cookie: cookie) }

  let(:cookie) { 'sess-abc' }

  describe '#get_note' do
    let!(:stub) do
      stub_request(:get, 'https://substack.com/api/v1/reader/comment/123')
        .with(headers: { 'Cookie' => 'substack.sid=sess-abc' })
        .to_return(status: 200, body: { 'comment' => { 'id' => 123 } }.to_json)
    end

    it { expect(client.get_note(123)).to eq({ 'comment' => { 'id' => 123 } }) }

    it 'sends the session cookie' do
      client.get_note(123)
      expect(stub).to have_been_requested
    end
  end

  describe '#create_note' do
    let(:body_json) { { 'type' => 'doc', 'content' => [] } }
    let!(:stub) do
      stub_request(:post, 'https://substack.com/api/v1/comment/feed')
        .with(body: hash_including('bodyJson' => body_json, 'tabId' => 'for-you'))
        .to_return(status: 200, body: { 'id' => 999 }.to_json)
    end

    it { expect(client.create_note(body_json)).to eq({ 'id' => 999 }) }

    it 'posts the bodyJson payload' do
      client.create_note(body_json)
      expect(stub).to have_been_requested
    end
  end

  describe '#delete_note' do
    before { stub_request(:delete, 'https://substack.com/api/v1/comment/123').to_return(status: 200, body: '') }

    it { expect(client.delete_note(123)).to eq({}) }
  end

  describe 'rate limiting' do
    before { allow(client).to receive(:backoff_sleep) }

    context 'retries after a 429 then succeeds' do
      before do
        stub_request(:get, 'https://substack.com/api/v1/reader/comment/1')
          .to_return({ status: 429, headers: { 'Retry-After' => '0' } }, { status: 200, body: { 'ok' => true }.to_json })
      end

      it { expect(client.get_note(1)).to eq({ 'ok' => true }) }
      it 'backs off before retrying' do
        client.get_note(1)
        expect(client).to have_received(:backoff_sleep)
      end
    end

    context 'gives up after MAX_RETRIES of persistent 429' do
      before { stub_request(:get, %r{substack\.com}).to_return(status: 429, body: 'Too Many Requests') }
      it { expect { client.get_note(1) }.to raise_error(Substack::Client::Error, /429/) }
    end
  end

  describe 'error handling' do
    context 'auth failure' do
      before { stub_request(:get, %r{substack\.com}).to_return(status: 403, body: 'nope') }
      it { expect { client.get_note(1) }.to raise_error(Substack::Client::AuthError) }
    end

    context 'other failure' do
      before { stub_request(:get, %r{substack\.com}).to_return(status: 500, body: 'boom') }
      it { expect { client.get_note(1) }.to raise_error(Substack::Client::Error, /500/) }
    end

    context 'missing cookie' do
      let(:cookie) { nil }
      it { expect { client.get_note(1) }.to raise_error(Substack::Client::AuthError, /No Substack session/) }
    end
  end
end

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

  describe '#create_note with attachments' do
    let!(:stub) do
      stub_request(:post, 'https://substack.com/api/v1/comment/feed')
        .with(body: hash_including('attachmentIds' => ['att-1']))
        .to_return(status: 200, body: '{}')
    end

    it 'includes attachmentIds in the payload' do
      client.create_note({ 'type' => 'doc' }, attachment_ids: ['att-1'])
      expect(stub).to have_been_requested
    end
  end

  describe '#create_attachment' do
    before do
      stub_request(:post, 'https://substack.com/api/v1/comment/attachment')
        .with(body: hash_including('url' => 'https://x.com/p/y', 'type' => 'link'))
        .to_return(status: 200, body: { 'id' => 'att-9' }.to_json)
    end

    it { expect(client.create_attachment('https://x.com/p/y')).to eq 'att-9' }
  end

  describe '#delete_note' do
    before { stub_request(:delete, 'https://substack.com/api/v1/comment/123').to_return(status: 200, body: '') }

    it { expect(client.delete_note(123)).to eq({}) }
  end

  describe 'drafts' do
    subject(:client) { described_class.new(session_cookie: cookie, publication_host: host) }

    let(:host) { 'pub.substack.com' }
    let(:doc) { { 'type' => 'doc', 'content' => [] } }
    let(:bylines) { [{ id: 42, is_guest: false }] }

    describe '#create_draft' do
      let!(:stub) do
        stub_request(:post, 'https://pub.substack.com/api/v1/drafts')
          .with(headers: { 'Cookie' => 'substack.sid=sess-abc' },
                body: hash_including('draft_title' => 'Hi', 'draft_body' => doc.to_json,
                                     'type' => 'newsletter', 'audience' => 'everyone'))
          .to_return(status: 200, body: { 'id' => 7 }.to_json)
      end

      it { expect(client.create_draft(title: 'Hi', subtitle: 'yo', body_doc: doc, bylines: bylines)).to eq({ 'id' => 7 }) }

      it 'serialises the body doc and posts to the publication host' do
        client.create_draft(title: 'Hi', subtitle: 'yo', body_doc: doc, bylines: bylines)
        expect(stub).to have_been_requested
      end
    end

    describe '#update_draft' do
      let!(:stub) do
        stub_request(:put, 'https://pub.substack.com/api/v1/drafts/7')
          .with(body: hash_including('draft_title' => 'Edited'))
          .to_return(status: 200, body: { 'id' => 7 }.to_json)
      end

      it 'PUTs the changed attributes' do
        client.update_draft(7, draft_title: 'Edited')
        expect(stub).to have_been_requested
      end
    end

    describe '#get_draft' do
      before { stub_request(:get, 'https://pub.substack.com/api/v1/drafts/7').to_return(status: 200, body: { 'id' => 7 }.to_json) }

      it { expect(client.get_draft(7)).to eq({ 'id' => 7 }) }
    end

    describe '#delete_draft' do
      before { stub_request(:delete, 'https://pub.substack.com/api/v1/drafts/7').to_return(status: 200, body: '') }

      it { expect(client.delete_draft(7)).to eq({}) }
    end

    describe '#publish_draft' do
      let!(:stub) do
        stub_request(:post, 'https://pub.substack.com/api/v1/drafts/7/publish')
          .with(body: hash_including('send_email' => false))
          .to_return(status: 200, body: '{}')
      end

      it 'posts to the publish endpoint with send_email false' do
        client.publish_draft(7)
        expect(stub).to have_been_requested
      end
    end

    describe '#add_tag' do
      let!(:stub) { stub_request(:post, 'https://pub.substack.com/api/v1/post/42/tag/tag-uuid').to_return(status: 200, body: '{}') }

      it 'posts to the tag path (tag id in the path, empty body)' do
        client.add_tag(42, 'tag-uuid')
        expect(stub).to have_been_requested
      end
    end

    describe '#upload_image' do
      before do
        stub_request(:post, 'https://pub.substack.com/api/v1/image')
          .with(body: hash_including('image' => 'data:image/png;base64,AAAA'))
          .to_return(status: 200, body: { 'url' => 'https://cdn/x.png' }.to_json)
      end

      it { expect(client.upload_image('data:image/png;base64,AAAA')).to eq 'https://cdn/x.png' }
    end

    context 'without a publication host' do
      let(:host) { nil }
      it { expect { client.get_draft(7) }.to raise_error(Substack::Client::Error, /publication host/) }
    end
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

    context 'retries a transient 502 then succeeds' do
      before do
        stub_request(:get, 'https://substack.com/api/v1/reader/comment/1')
          .to_return({ status: 502, body: '<html>' }, { status: 200, body: { 'ok' => true }.to_json })
      end

      it { expect(client.get_note(1)).to eq({ 'ok' => true }) }
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

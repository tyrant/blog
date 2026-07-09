# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::PostSyncer do
  subject(:sync) { described_class.execute(post_id: post.id, client: client, config: config) }

  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:post) { create :post, site: site, layout: layout }
  let(:client) { instance_double(Substack::Client) }
  let(:config) { instance_double(SubstackSyncConfig, author_id: 42, publication_host: 'pub.substack.com') }

  before { post.update_column(:content_cache, '<p>Body</p>') }

  describe 'a post with no draft yet' do
    before { allow(client).to receive(:create_draft).and_return('id' => 555) }

    it 'creates a draft' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(title: post.title, subtitle: ''))
    end

    it 'sends the byline built from the configured author id' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(bylines: [{ id: 42, is_guest: false }]))
    end

    it 'stores the returned draft id on the post' do
      sync
      expect(post.reload.substack_draft_id).to eq 555
    end

    it 'returns the new draft id' do
      expect(sync).to eq 555
    end
  end

  describe 'a post already mirrored to a draft' do
    before do
      post.update_column(:substack_draft_id, 999)
      allow(client).to receive(:update_draft)
    end

    it 'updates the existing draft' do
      sync
      expect(client).to have_received(:update_draft).with(999, hash_including(:draft_body, draft_title: post.title))
    end

    it 'does not create a new draft' do
      allow(client).to receive(:create_draft)
      sync
      expect(client).to_not have_received(:create_draft)
    end
  end

  describe 'image handling' do
    before do
      post.update_column(:content_cache, '<p><img src="http://ex.com/a.jpg"></p>')
      stub_request(:get, 'http://ex.com/a.jpg').to_return(status: 200, body: 'BYTES', headers: { 'Content-Type' => 'image/jpeg' })
      allow(client).to receive(:upload_image).and_return('https://cdn/x.jpg')
      allow(client).to receive(:create_draft).and_return('id' => 1)
    end

    it 'uploads the image as a data URI' do
      sync
      expect(client).to have_received(:upload_image).with(%r{\Adata:image/jpeg;base64,})
    end

    it 'references the returned CDN url in the draft body' do
      sync
      expect(client).to have_received(:create_draft) do |args|
        expect(args[:body_doc].to_json).to include('https://cdn/x.jpg')
      end
    end
  end
end

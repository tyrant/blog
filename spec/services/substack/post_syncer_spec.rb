# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::PostSyncer do
  subject(:sync) { described_class.execute(post_id: post.id, client: client, config: config) }

  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:post) { create :post, site: site, layout: layout }
  let(:client) { instance_double(Substack::Client) }
  let(:footer) { [{ 'type' => 'button', 'attrs' => { 'text' => 'Subscribe now' } }] }
  let(:config) do
    instance_double(SubstackSyncConfig, author_id: 42, publication_host: 'pub.substack.com',
                                        subtitle: 'The fixed subtitle', footer_json: footer)
  end

  before { post.update_column(:content_cache, '<p>Body</p>') }

  describe 'a post with no draft yet' do
    before { allow(client).to receive(:create_draft).and_return('id' => 555) }

    it 'creates a draft' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(title: post.title))
    end

    it 'sends the configured subtitle' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(subtitle: 'The fixed subtitle'))
    end

    it 'appends the Original link heading pointing at the canonical post url' do
      sync
      expect(client).to have_received(:create_draft) do |args|
        heading = args[:body_doc]['content'].find { |b| b['type'] == 'heading' && b.dig('attrs', 'level') == 5 }
        expect(heading['content'].last['marks'].first['attrs']['href']).to eq post.url.sub(%r{\A//}, 'https://')
      end
    end

    it 'appends the configured footer blocks last' do
      sync
      expect(client).to have_received(:create_draft) do |args|
        expect(args[:body_doc]['content'].last).to eq(footer.first)
      end
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

  describe 'a source post that bakes its own Original link into the body' do
    before do
      post.update_column(:content_cache,
        '<p><em>Original: </em><a href="http://old/stale">http://old/stale</a></p><p>Body</p>')
      allow(client).to receive(:create_draft).and_return('id' => 1)
    end

    def original_blocks(doc)
      doc['content'].select do |b|
        next false unless %w[paragraph heading].include?(b['type'])

        b['content'].to_a.map { |n| n['text'] }.join.strip.match?(/\AOriginal:/i)
      end
    end

    it 'keeps exactly one Original block' do
      sync
      expect(client).to have_received(:create_draft) { |args| expect(original_blocks(args[:body_doc]).size).to eq 1 }
    end

    it 'the surviving Original block is the canonical h5 pointing at post.url' do
      sync
      expect(client).to have_received(:create_draft) do |args|
        block = original_blocks(args[:body_doc]).first
        expect(block['attrs']['level']).to eq 5
        expect(block['content'].last['marks'].first['attrs']['href']).to eq post.url.sub(%r{\A//}, 'https://')
      end
    end
  end

  describe 'a post already mirrored to a draft' do
    before do
      post.update_column(:substack_draft_id, 999)
      allow(client).to receive(:update_draft)
    end

    it 'updates the existing draft' do
      sync
      expect(client).to have_received(:update_draft).with(999, hash_including(:draft_body, draft_title: post.title, draft_subtitle: 'The fixed subtitle'))
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

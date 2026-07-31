# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bluesky::PostSyncer do
  subject(:sync) { described_class.execute(post_id: post.id, client: client, config: config) }

  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:post) { create :post, site: site, layout: layout }
  let!(:bluesky_category) { create :category, site: site, label: 'Bluesky' }
  let(:client) { instance_double(Bluesky::Client) }
  let(:config) { instance_double(BlueskySyncConfig, lead_for: 'New on the blog', handle: 'me.bsky.social') }
  let(:created) { { 'uri' => 'at://did:plc:me/app.bsky.feed.post/rk9', 'cid' => 'cid9' } }

  def bluesky_categorization
    post.categorizations.joins(:category).find_by(comfy_cms_categories: { label: 'Bluesky' })
  end

  before { post.update_column(:content_cache, '<p>Body text</p>') }

  describe 'a post with no Bluesky link' do
    before { allow(client).to receive(:create_post).and_return(created) }

    it 'posts a record to Bluesky' do
      sync
      expect(client).to have_received(:create_post)
    end

    it 'sends the teaser text carrying the canonical link' do
      sync
      expect(client).to have_received(:create_post).with(hash_including('text' => a_string_including(post.url)))
    end

    it 'attaches a link facet' do
      sync
      expect(client).to have_received(:create_post).with(hash_including('facets' => be_present))
    end

    it 'includes an external link card' do
      sync
      expect(client).to have_received(:create_post)
        .with(hash_including('embed' => hash_including('$type' => 'app.bsky.embed.external')))
    end

    it 'sends an absolute https url in the card (not Comfy’s protocol-relative one)' do
      sync
      expect(client).to have_received(:create_post)
        .with(hash_including('embed' => hash_including('external' => hash_including('uri' => a_string_starting_with('https://')))))
    end

    it 'sends an absolute https url in the teaser text' do
      sync
      expect(client).to have_received(:create_post).with(hash_including('text' => a_string_including('https://')))
    end

    it 'builds the card description from the post body' do
      sync
      expect(client).to have_received(:create_post)
        .with(hash_including('embed' => hash_including('external' => hash_including('description' => 'Body text'))))
    end

    it 'records a Bluesky categorization holding the returned uri' do
      sync
      expect(bluesky_categorization.data['uri']).to eq 'at://did:plc:me/app.bsky.feed.post/rk9'
    end

    it 'stores the cid on the categorization' do
      sync
      expect(bluesky_categorization.data['cid']).to eq 'cid9'
    end

    it 'stores the public permalink as the categorization url' do
      sync
      expect(bluesky_categorization.url).to eq 'https://bsky.app/profile/me.bsky.social/post/rk9'
    end

    it 'returns the created uri' do
      expect(sync).to eq 'at://did:plc:me/app.bsky.feed.post/rk9'
    end
  end

  describe 'the link-card thumbnail' do
    before { allow(client).to receive(:create_post).and_return(created) }

    context 'a post with no image' do
      it 'omits the thumb and never uploads a blob' do
        allow(client).to receive(:upload_blob)
        sync
        expect(client).to_not have_received(:upload_blob)
      end
    end

    context 'a post with a remote image' do
      let(:blob) { { '$type' => 'blob', 'ref' => { '$link' => 'bafk1' } } }

      before do
        post.update_column(:content_cache, '<img src="https://cdn.example/pic.jpg">')
        stub_request(:get, 'https://cdn.example/pic.jpg')
          .to_return(status: 200, body: 'imgbytes', headers: { 'Content-Type' => 'image/jpeg' })
        allow(client).to receive(:upload_blob).and_return(blob)
      end

      it 'uploads the fetched image bytes' do
        sync
        expect(client).to have_received(:upload_blob).with('imgbytes', 'image/jpeg')
      end

      it 'attaches the returned blob as the card thumb' do
        sync
        expect(client).to have_received(:create_post)
          .with(hash_including('embed' => hash_including('external' => hash_including('thumb' => blob))))
      end
    end

    context 'a post with a local ActiveStorage image' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(io: File.open(Rails.root.join('spec/fixtures/files/test_image.jpg')),
                                               filename: 'test_image.jpg', content_type: 'image/jpeg')
      end
      let(:as_url) { "http://localhost:3000/rails/active_storage/blobs/redirect/#{blob.signed_id}/test_image.jpg" }
      let(:thumb_blob) { { '$type' => 'blob', 'ref' => { '$link' => 'bafk2' } } }

      before do
        post.update_column(:content_cache, "<img src=\"#{as_url}\">")
        allow(client).to receive(:upload_blob).and_return(thumb_blob)
      end

      it 'uploads the resized blob bytes as an image' do
        sync
        expect(client).to have_received(:upload_blob).with(kind_of(String), 'image/jpeg')
      end

      it 'attaches the returned blob as the card thumb' do
        sync
        expect(client).to have_received(:create_post)
          .with(hash_including('embed' => hash_including('external' => hash_including('thumb' => thumb_blob))))
      end
    end

    context 'a remote image larger than Bluesky’s blob limit' do
      before do
        post.update_column(:content_cache, '<img src="https://cdn.example/huge.jpg">')
        stub_request(:get, 'https://cdn.example/huge.jpg')
          .to_return(status: 200, body: 'x' * (described_class::MAX_BLOB_BYTES + 1), headers: { 'Content-Type' => 'image/jpeg' })
        allow(client).to receive(:upload_blob)
      end

      it 'skips the upload rather than failing' do
        sync
        expect(client).to_not have_received(:upload_blob)
      end
    end
  end

  describe 'a post already synced to Bluesky' do
    before do
      create :categorization, category: bluesky_category, categorized: post,
                              url: 'https://bsky.app/profile/me/post/old', data: { 'uri' => 'at://old', 'cid' => 'c' }
      allow(client).to receive(:create_post)
    end

    it 'does not post again' do
      sync
      expect(client).to_not have_received(:create_post)
    end

    it 'returns the existing uri' do
      expect(sync).to eq 'at://old'
    end
  end
end

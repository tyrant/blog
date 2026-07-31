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

    it 'serializes on the post row to prevent duplicate posts' do
      expect_any_instance_of(Comfy::Blog::Post).to receive(:with_lock)
      sync
    end
  end

  describe 'the link-card thumbnail' do
    before do
      allow(client).to receive(:create_post).and_return(created)
      # The resize seam runs the vipsthumbnail CLI in a subprocess; stub it so
      # wiring tests don't depend on the binary. Exercised for real below.
      allow_any_instance_of(described_class).to receive(:resize_to_jpeg).and_return('jpegbytes')
    end

    context 'a post with no image' do
      it 'never uploads a blob' do
        allow(client).to receive(:upload_blob)
        sync
        expect(client).to_not have_received(:upload_blob)
      end
    end

    context 'a post with a remote image' do
      let(:blob) { { '$type' => 'blob', 'ref' => { '$link' => 'bafk1' } } }

      before do
        post.update_column(:content_cache, '<img src="https://cdn.example/pic.png">')
        stub_request(:get, 'https://cdn.example/pic.png')
          .to_return(status: 200, body: 'rawpng', headers: { 'Content-Type' => 'image/png' })
        allow(client).to receive(:upload_blob).and_return(blob)
      end

      it 'uploads the resized jpeg' do
        sync
        expect(client).to have_received(:upload_blob).with('jpegbytes', 'image/jpeg')
      end

      it 'attaches the returned blob as the card thumb' do
        sync
        expect(client).to have_received(:create_post)
          .with(hash_including('embed' => hash_including('external' => hash_including('thumb' => blob))))
      end
    end

    context 'a post with a local ActiveStorage image' do
      let(:image_blob) do
        ActiveStorage::Blob.create_and_upload!(io: File.open(Rails.root.join('spec/fixtures/files/test_image.jpg')),
                                               filename: 'test_image.jpg', content_type: 'image/jpeg')
      end
      let(:as_url) { "http://localhost:3000/rails/active_storage/blobs/redirect/#{image_blob.signed_id}/test_image.jpg" }

      before do
        post.update_column(:content_cache, "<img src=\"#{as_url}\">")
        allow(client).to receive(:upload_blob).and_return({ '$type' => 'blob' })
      end

      it 'downloads the blob, resizes and uploads it' do
        sync
        expect(client).to have_received(:upload_blob).with('jpegbytes', 'image/jpeg')
      end
    end

    context 'an unsupported image type' do
      before do
        post.update_column(:content_cache, '<img src="https://cdn.example/pic.svg">')
        stub_request(:get, 'https://cdn.example/pic.svg')
          .to_return(status: 200, body: '<svg/>', headers: { 'Content-Type' => 'image/svg+xml' })
        allow(client).to receive(:upload_blob)
      end

      it 'is skipped before any resize' do
        sync
        expect(client).to_not have_received(:upload_blob)
      end
    end

    context 'when the resize fails or the binary is missing' do
      before do
        post.update_column(:content_cache, '<img src="https://cdn.example/pic.png">')
        stub_request(:get, 'https://cdn.example/pic.png')
          .to_return(status: 200, body: 'rawpng', headers: { 'Content-Type' => 'image/png' })
        allow_any_instance_of(described_class).to receive(:resize_to_jpeg).and_return(nil)
        allow(client).to receive(:upload_blob)
      end

      it 'skips the upload rather than failing' do
        sync
        expect(client).to_not have_received(:upload_blob)
      end
    end

    context 'a resized image larger than Bluesky’s blob limit' do
      before do
        post.update_column(:content_cache, '<img src="https://cdn.example/pic.png">')
        stub_request(:get, 'https://cdn.example/pic.png')
          .to_return(status: 200, body: 'rawpng', headers: { 'Content-Type' => 'image/png' })
        allow_any_instance_of(described_class).to receive(:resize_to_jpeg).and_return('x' * (described_class::MAX_BLOB_BYTES + 1))
        allow(client).to receive(:upload_blob)
      end

      it 'skips the upload' do
        sync
        expect(client).to_not have_received(:upload_blob)
      end
    end
  end

  describe '#resize_to_jpeg' do
    subject(:syncer) { described_class.allocate }

    let(:jpeg_bytes) { File.binread(Rails.root.join('spec/fixtures/files/test_image.jpg')) }

    context 'with the vipsthumbnail CLI', if: system('command -v vipsthumbnail > /dev/null 2>&1') do
      it 'returns jpeg bytes (SOI marker)' do
        expect(syncer.send(:resize_to_jpeg, jpeg_bytes, '.jpg')[0, 2].bytes).to eq [0xFF, 0xD8]
      end
    end

    context 'when the binary is missing' do
      before { allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT) }

      it { expect(syncer.send(:resize_to_jpeg, jpeg_bytes, '.jpg')).to be_nil }
    end

    context 'when the CLI exits non-zero' do
      before do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(['', 'bad image', status])
      end

      it { expect(syncer.send(:resize_to_jpeg, jpeg_bytes, '.jpg')).to be_nil }
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

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

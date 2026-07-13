# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::PostSyncer do
  subject(:sync) { described_class.execute(post_id: post.id, client: client, config: config) }

  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:post) { create :post, site: site, layout: layout }
  let!(:substack_category) { create :category, site: site, label: 'Substack' }
  let(:client) { instance_double(Substack::Client) }
  let(:footer) { [{ 'type' => 'button', 'attrs' => { 'text' => 'Subscribe now' } }] }
  let(:tags) { [{ 'name' => 'writing', 'id' => 't1' }, { 'name' => 'comedy', 'id' => 't2' }] }
  let(:config) do
    instance_double(SubstackSyncConfig, author_id: 42, publication_host: 'pub.substack.com',
                                        subtitle: 'The fixed subtitle', footer_json: footer, default_tags: tags)
  end

  def substack_categorization
    post.categorizations.joins(:category).find_by(comfy_cms_categories: { label: 'Substack' })
  end

  def link!(url:, data:)
    create :categorization, category: substack_category, categorized: post, url: url, data: data
  end

  before do
    post.update_column(:content_cache, '<p>Body</p>')
    allow(client).to receive(:update_draft)
    allow(client).to receive(:add_tag)
  end

  describe 'a post with no Substack link' do
    before { allow(client).to receive(:create_draft).and_return('id' => 555, 'is_published' => false, 'slug' => nil) }

    it 'creates a draft with the configured subtitle' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(title: post.title, subtitle: 'The fixed subtitle'))
    end

    it 'sets the new draft slug to the Comfy post slug' do
      post.update_column(:slug, 'my-post-slug')
      sync
      expect(client).to have_received(:update_draft).with(555, hash_including(slug: 'my-post-slug'))
    end

    it 'normalises the slug to Substack’s charset' do
      post.update_column(:slug, 'My_Post')
      sync
      expect(client).to have_received(:update_draft).with(555, hash_including(slug: 'my-post'))
    end

    it 'skips the slug when it is too short for Substack' do
      post.update_column(:slug, '3')
      sync
      expect(client).to_not have_received(:update_draft)
    end

    it 'sends the byline built from the configured author id' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(bylines: [{ id: 42, is_guest: false }]))
    end

    it 'defaults a new draft to the everyone audience' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(audience: 'everyone'))
    end

    it 'creates a paid draft when the post is marked paid' do
      post.update_column(:substack_audience, 'only_paid')
      sync
      expect(client).to have_received(:create_draft).with(hash_including(audience: 'only_paid'))
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
      expect(client).to have_received(:create_draft) { |args| expect(args[:body_doc]['content'].last).to eq(footer.first) }
    end

    it 'creates a Substack categorization storing the draft id' do
      sync
      expect(substack_categorization.data['id']).to eq 555
    end

    it 'stores the draft editor URL on the categorization' do
      sync
      expect(substack_categorization.url).to eq 'https://pub.substack.com/publish/post/555'
    end

    it 'assigns each configured default tag to the new post' do
      sync
      expect(client).to have_received(:add_tag).with(555, 't1')
      expect(client).to have_received(:add_tag).with(555, 't2')
    end

    it 'returns the new draft id' do
      expect(sync).to eq 555
    end
  end

  describe 'a source post that bakes its own Original link into the body' do
    before do
      post.update_column(:content_cache,
        '<p><em>Original: </em><a href="http://old/stale">http://old/stale</a></p><p>Body</p>')
      allow(client).to receive(:create_draft).and_return('id' => 1, 'is_published' => false, 'slug' => nil)
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

  describe 'a post linked to a published Substack post' do
    let!(:categorization) { link!(url: 'https://pub.substack.com/p/old-slug', data: { 'id' => 778 }) }

    before do
      allow(client).to receive(:get_draft).with(778).and_return('id' => 778, 'is_published' => true, 'slug' => 'live-slug')
      allow(client).to receive(:update_draft)
      allow(client).to receive(:publish_draft)
      allow(client).to receive(:create_draft)
    end

    it 'updates the draft by id' do
      sync
      expect(client).to have_received(:update_draft).with(778, hash_including(:draft_body, draft_title: post.title, should_send_email: false))
    end

    it 'publishes the edits immediately' do
      sync
      expect(client).to have_received(:publish_draft).with(778)
    end

    it 'never re-slugs a published post' do
      post.update_column(:slug, 'a-new-slug')
      sync
      expect(client).to_not have_received(:update_draft).with(anything, hash_including(:slug))
    end

    it 'reconciles the categorization URL to the canonical public URL' do
      sync
      expect(categorization.reload.url).to eq 'https://pub.substack.com/p/live-slug'
    end

    it 'never creates a parallel draft' do
      sync
      expect(client).to_not have_received(:create_draft)
    end

    it 'returns the post id' do
      expect(sync).to eq 778
    end
  end

  describe 'a post linked to an unpublished draft' do
    let!(:categorization) { link!(url: 'https://pub.substack.com/publish/post/900', data: { 'id' => 900 }) }

    before do
      allow(client).to receive(:get_draft).with(900).and_return('id' => 900, 'is_published' => false, 'slug' => nil)
      allow(client).to receive(:update_draft)
      allow(client).to receive(:publish_draft)
    end

    it 'updates the draft' do
      sync
      expect(client).to have_received(:update_draft).with(900, hash_including(:draft_body))
    end

    it 'mirrors the post audience on update' do
      post.update_column(:substack_audience, 'only_paid')
      sync
      expect(client).to have_received(:update_draft).with(900, hash_including(audience: 'only_paid'))
    end

    it 'does not auto-publish' do
      sync
      expect(client).to_not have_received(:publish_draft)
    end

    it 're-slugs the still-draft post to the Comfy slug' do
      post.update_column(:slug, 'draft-slug')
      sync
      expect(client).to have_received(:update_draft).with(900, hash_including(slug: 'draft-slug'))
    end

    it 'keeps the draft editor URL' do
      sync
      expect(categorization.reload.url).to eq 'https://pub.substack.com/publish/post/900'
    end
  end

  describe 'a Substack categorization that has no id and no published URL' do
    let!(:categorization) { link!(url: '', data: {}) }

    before { allow(client).to receive(:create_draft).and_return('id' => 42, 'is_published' => false, 'slug' => nil) }

    it 'populates the existing categorization rather than duplicating it' do
      sync
      expect(post.categorizations.joins(:category).where(comfy_cms_categories: { label: 'Substack' }).count).to eq 1
    end

    it 'records the new draft id on it' do
      sync
      expect(categorization.reload.data['id']).to eq 42
    end
  end

  describe 'a legacy categorization with a published URL but no stored id' do
    let!(:categorization) { link!(url: 'https://pub.substack.com/p/legacy', data: {}) }

    before do
      allow(client).to receive(:get_post).with('https://pub.substack.com/p/legacy')
        .and_return('id' => 654, 'is_published' => true, 'slug' => 'legacy')
      allow(client).to receive(:get_draft).with(654).and_return('id' => 654, 'is_published' => true, 'slug' => 'legacy')
      allow(client).to receive(:update_draft)
      allow(client).to receive(:publish_draft)
      allow(client).to receive(:create_draft)
    end

    it 'resolves the id from the URL and edits in place' do
      sync
      expect(client).to have_received(:update_draft).with(654, anything)
    end

    it 'backfills the resolved id onto the categorization' do
      sync
      expect(categorization.reload.data['id']).to eq 654
    end

    it 'does not create a parallel draft' do
      sync
      expect(client).to_not have_received(:create_draft)
    end
  end

  describe 'image handling' do
    before do
      post.update_column(:content_cache, '<p><img src="http://ex.com/a.jpg"></p>')
      stub_request(:get, 'http://ex.com/a.jpg').to_return(status: 200, body: 'BYTES', headers: { 'Content-Type' => 'image/jpeg' })
      allow(client).to receive(:upload_image).and_return('https://cdn/x.jpg')
      allow(client).to receive(:create_draft).and_return('id' => 1, 'is_published' => false, 'slug' => nil)
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

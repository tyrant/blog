# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::ReviewsPageSyncer do
  let(:config) { SubstackSyncConfig.instance }
  let(:client) { instance_double(Substack::Client) }

  def quote(attrs = {})
    SubstackQuotation.create!({ quotation: 'a blurb', comment_url: 'https://sub/p/a/comment/1',
                                post_url: 'https://sub/p/a', post_title: 'A', author_name: 'Eva',
                                author_url: 'https://substack.com/@eva' }.merge(attrs))
  end

  def body_doc
    doc = nil
    expect(client).to have_received(:update_draft) { |_id, attrs| doc = JSON.parse(attrs[:draft_body]) }
    doc
  end

  subject(:sync) { described_class.execute(client: client, config: config) }

  context 'with a configured draft id' do
    let!(:first) { quote(quotation: 'first') }

    before do
      config.update!(reviews_draft_id: 555)
      allow(client).to receive(:get_draft).with(555)
        .and_return('draft_title' => 'Reviews', 'draft_subtitle' => '', 'is_published' => false)
      allow(client).to receive(:update_draft)
      allow(Substack::QuotationEmbed).to receive(:execute).and_return(nil)
    end

    it 'writes to the configured draft' do
      sync
      expect(client).to have_received(:update_draft).with(555, hash_including(draft_body: kind_of(String)))
    end

    it 'preserves the existing title and subtitle' do
      sync
      expect(client).to have_received(:update_draft).with(555, hash_including(draft_title: 'Reviews', draft_subtitle: ''))
    end

    it 'lists every featurable quotation as a blockquote' do
      quote(quotation: 'second')
      sync
      expect(body_doc['content'].count { |b| b['type'] == 'blockquote' }).to eq 2
    end

    it 'renders quotations in stored position order' do
      first.update!(position: 2)
      quote(quotation: 'second').update!(position: 1)
      sync
      quotes = body_doc['content'].select { |b| b['type'] == 'blockquote' }
        .map { |b| b['content'][0]['content'][0]['text'] }
      expect(quotes).to eq ['“second”', '“first”']
    end

    it 'skips quotations missing post/author links' do
      quote(quotation: 'incomplete', post_url: nil, author_url: nil)
      sync
      expect(body_doc['content'].count { |b| b['type'] == 'blockquote' }).to eq 1
    end

    it 'falls back to a plain post-title heading when no embed can be built' do
      sync
      types = body_doc['content'].map { |b| b['type'] }
      expect(types.first).to eq 'heading'
      expect(body_doc['content'].none? { |b| b['type'] == 'digestPostEmbed' }).to be true
    end

    context 'with a stored embed snapshot' do
      let(:snapshot) { { 'size' => 'sm', 'id' => 192565792, 'title' => 'A', 'isEditorNode' => true } }
      let!(:first) { quote(quotation: 'first', post_embed: snapshot) }

      it 'leads each review with the snapshot as a small post-embed card' do
        sync
        card = body_doc['content'].first
        expect(card['type']).to eq 'digestPostEmbed'
        expect(card['attrs']).to include(snapshot)
      end

      it 'drops the post-title heading in favour of the card' do
        sync
        types = body_doc['content'].map { |b| b['type'] }
        expect(types.first(3)).to eq %w[digestPostEmbed blockquote paragraph]
      end

      it 'gives each card a unique nodeId' do
        quote(quotation: 'second', post_embed: snapshot)
        sync
        ids = body_doc['content'].select { |b| b['type'] == 'digestPostEmbed' }.map { |b| b['attrs']['nodeId'] }
        expect(ids.uniq.size).to eq 2
      end
    end

    context 'when a quotation has no snapshot yet' do
      let(:snapshot) { { 'size' => 'sm', 'id' => 99, 'isEditorNode' => true } }

      before { allow(Substack::QuotationEmbed).to receive(:execute).and_return(snapshot) }

      it 'lazily builds and stores the snapshot' do
        sync
        expect(first.reload.post_embed).to eq snapshot
      end

      it 'fetches once per post url across duplicate quotations' do
        quote(quotation: 'second')
        sync
        expect(Substack::QuotationEmbed).to have_received(:execute).once
      end
    end

    context 'with a manually-authored intro above the review list' do
      let(:intro) { { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Good gracious gumdrops.' }] } }
      let(:existing) { { 'type' => 'doc', 'content' => [intro] + Substack::QuotationBlock.build(first) } }

      before do
        allow(client).to receive(:get_draft).with(555)
          .and_return('draft_title' => 'Reviews', 'draft_subtitle' => '', 'is_published' => false,
                      'draft_body' => JSON.generate(existing))
      end

      it 'keeps the intro block above the regenerated triplets' do
        sync
        expect(body_doc['content'].first).to eq intro
      end

      it 'regenerates the review list once, not stacking the old run' do
        sync
        expect(body_doc['content'].count { |b| b['type'] == 'blockquote' }).to eq 1
      end

      context 'when the first review carries a cover thumbnail' do
        let(:thumb) { { 'type' => 'captionedImage', 'content' => [{ 'type' => 'image2', 'attrs' => { 'src' => 'x' } }] } }
        let(:existing) { { 'type' => 'doc', 'content' => [intro, thumb] + Substack::QuotationBlock.build(first) } }

        it 'folds the leading thumbnail into the review region, not the intro' do
          sync
          expect(body_doc['content'].first).to eq intro
        end
      end
    end

    it 'does not publish while it is still a draft' do
      allow(client).to receive(:publish_draft)
      sync
      expect(client).to_not have_received(:publish_draft)
    end
  end

  context 'when the page is already published' do
    before do
      quote
      config.update!(reviews_draft_id: 555)
      allow(client).to receive(:get_draft)
        .and_return('draft_title' => 'Reviews', 'draft_subtitle' => '', 'is_published' => true)
      allow(client).to receive(:update_draft)
      allow(client).to receive(:publish_draft)
      allow(Substack::QuotationEmbed).to receive(:execute).and_return(nil)
    end

    it 'republishes to push the edit live' do
      sync
      expect(client).to have_received(:publish_draft).with(555)
    end
  end

  context 'without a configured draft id' do
    before { config.update!(reviews_draft_id: nil) }

    it 'does nothing' do
      expect(client).to_not receive(:get_draft)
      sync
    end
  end

  context 'with an empty pool' do
    before do
      config.update!(reviews_draft_id: 555)
      allow(client).to receive(:get_draft)
        .and_return('draft_title' => 'Reviews', 'draft_subtitle' => '', 'is_published' => false)
      allow(client).to receive(:update_draft)
    end

    it 'writes a valid empty document' do
      sync
      expect(body_doc['content']).to eq([{ 'type' => 'paragraph' }])
    end
  end
end

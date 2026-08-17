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

  # The syncer triggers a nav sync at the end; stub it out by default so it never
  # touches the client double (its own behaviour is covered in nav_syncer_spec).
  before { allow(Substack::NavSyncer).to receive(:execute).and_return([]) }

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

    it 'titles page 1 and preserves the subtitle' do
      sync
      expect(client).to have_received(:update_draft).with(555, hash_including(draft_title: 'Sexyverse Advice Reviews Page 1'))
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

    describe 'navigation sync' do
      it 'triggers a nav sync after rebuilding the pages' do
        sync
        expect(Substack::NavSyncer).to have_received(:execute).with(client: client, config: config)
      end

      it 'still completes the rebuild when the nav sync fails' do
        allow(Substack::NavSyncer).to receive(:execute).and_raise(StandardError, 'cloudflare')
        expect { sync }.to_not raise_error
        expect(client).to have_received(:update_draft).with(555, anything)
      end
    end

    context 'with a cover image on the first review' do
      let!(:first) { quote(quotation: 'first', post_title: 'Cover Post', post_image_url: 'https://cdn/img.jpg') }

      it 'opens the page with a standard-width captioned banner image' do
        sync
        banner = body_doc['content'].first
        expect(banner['type']).to eq 'captionedImage'
        image = banner['content'].find { |n| n['type'] == 'image2' }
        expect(image['attrs']).to include('src' => 'https://cdn/img.jpg', 'imageSize' => 'normal', 'resizeWidth' => 728)
      end

      it 'captions the banner with the post title' do
        sync
        caption = body_doc['content'].first['content'].find { |n| n['type'] == 'caption' }
        expect(caption['content'][0]['text']).to eq 'Cover Post'
      end

      it 'omits the banner when the first review has no cover image' do
        first.update!(post_image_url: nil)
        sync
        expect(body_doc['content'].first['type']).to_not eq 'captionedImage'
      end
    end

    context 'when a previous sync already added a banner and intro' do
      let!(:first) { quote(quotation: 'first', post_title: 'Cover', post_image_url: 'https://cdn/new.jpg') }
      let(:intro)  { { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Welcome.' }] } }
      let(:stale_banner) { { 'type' => 'captionedImage', 'content' => [{ 'type' => 'image2', 'attrs' => { 'src' => 'https://cdn/old.jpg' } }] } }
      let(:existing) { { 'type' => 'doc', 'content' => [stale_banner, intro] + Substack::QuotationBlock.build(first) } }

      before do
        allow(client).to receive(:get_draft).with(555)
          .and_return('draft_title' => 'Reviews', 'draft_subtitle' => '', 'is_published' => false,
                      'draft_body' => JSON.generate(existing))
      end

      it 'rebuilds a single banner from the current cover, not the stale one' do
        sync
        images = body_doc['content'].select { |b| b['type'] == 'captionedImage' }
        expect(images.size).to eq 1
        expect(images.first['content'].find { |n| n['type'] == 'image2' }['attrs']['src']).to eq 'https://cdn/new.jpg'
      end

      it 'preserves the manually-authored intro' do
        sync
        expect(body_doc['content']).to include(intro)
      end
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

  context 'when the pool spans more than one page' do
    # PER_PAGE = 2, three quotations → page 1 gets two, page 2 gets one.
    let(:bodies) { {} }

    before do
      config.update!(reviews_draft_id: 555, publication_host: 'mikeyclarke.substack.com', reviews_page_size: 2)
      quote(quotation: 'one').update!(position: 0)
      quote(quotation: 'two').update!(position: 1)
      quote(quotation: 'three').update!(position: 2)
      allow(client).to receive(:get_draft).with(555)
        .and_return('draft_title' => 'Reviews', 'draft_subtitle' => '', 'is_published' => true, 'slug' => 'reviews')
      allow(client).to receive(:get_draft).with(556)
        .and_return('draft_title' => 'Reviews Page 2', 'draft_subtitle' => '', 'is_published' => true, 'slug' => 'reviews-page-2')
      allow(client).to receive(:create_draft).and_return('id' => 556)
      allow(client).to receive(:publish_draft)
      allow(client).to receive(:update_draft) do |id, attrs|
        bodies[id] = JSON.parse(attrs[:draft_body])['content'] if attrs[:draft_body]
      end
      allow(Substack::QuotationEmbed).to receive(:execute).and_return(nil)
    end

    it 'auto-creates the second page titled "Reviews Page 2"' do
      sync
      expect(client).to have_received(:create_draft).with(hash_including(title: 'Reviews Page 2')).once
    end

    it 'slugs the new page "reviews-page-2"' do
      sync
      expect(client).to have_received(:update_draft).with(556, hash_including(slug: 'reviews-page-2'))
    end

    it 'publishes the newly created page' do
      sync
      expect(client).to have_received(:publish_draft).with(556)
    end

    it 'records the new page id in the config' do
      sync
      expect(config.reload.reviews_extra_draft_ids).to eq [556]
    end

    it 'titles the two pages in order' do
      sync
      expect(client).to have_received(:update_draft).with(555, hash_including(draft_title: 'Sexyverse Advice Reviews Page 1'))
      expect(client).to have_received(:update_draft).with(556, hash_including(draft_title: 'Sexyverse Advice Reviews Page 2'))
    end

    it 'puts two reviews on page 1 and one on page 2' do
      sync
      expect(bodies[555].count { |b| b['type'] == 'blockquote' }).to eq 2
      expect(bodies[556].count { |b| b['type'] == 'blockquote' }).to eq 1
    end

    it 'distributes reviews in stored position order' do
      sync
      page1_quotes = bodies[555].select { |b| b['type'] == 'blockquote' }
        .map { |b| b['content'][0]['content'][0]['text'] }
      expect(page1_quotes).to eq ['“one”', '“two”']
    end

    it 'opens and closes each page with a centred pagination nav' do
      sync
      first, last = bodies[555].first, bodies[555].last
      expect([first, last].map { |b| b['type'] }).to eq %w[paragraph paragraph]
      expect([first, last].map { |b| b.dig('attrs', 'textAlign') }).to eq %w[center center]
    end

    it 'prefixes the pagination nav with "Reviews page: "' do
      sync
      expect(bodies[555].first['content'].first['text']).to eq 'Reviews page: '
    end

    it 'bolds the current page and links the others in the nav' do
      sync
      nav = bodies[555].first['content'].reject { |n| n['text'].strip.empty? }
      current = nav.find { |n| n['text'] == '1' }
      other   = nav.find { |n| n['text'] == '2' }
      expect(current['marks'].map { |m| m['type'] }).to eq %w[strong]
      expect(other['marks'].find { |m| m['type'] == 'link' }.dig('attrs', 'href'))
        .to eq 'https://mikeyclarke.substack.com/p/reviews-page-2'
    end
  end

  context 'with banners across multiple pages' do
    let(:bodies) { {} }

    before do
      config.update!(reviews_draft_id: 555, publication_host: 'mikeyclarke.substack.com', reviews_page_size: 2)
      quote(quotation: 'one',   post_title: 'First Post',  post_image_url: 'https://cdn/1.jpg').update!(position: 0)
      quote(quotation: 'two',   post_title: 'Second Post', post_image_url: 'https://cdn/2.jpg').update!(position: 1)
      quote(quotation: 'three', post_title: 'Third Post',  post_image_url: 'https://cdn/3.jpg').update!(position: 2)
      allow(client).to receive(:get_draft).with(555)
        .and_return('draft_subtitle' => '', 'is_published' => true, 'slug' => 'reviews')
      allow(client).to receive(:get_draft).with(556)
        .and_return('draft_subtitle' => '', 'is_published' => true, 'slug' => 'reviews-page-2')
      allow(client).to receive(:create_draft).and_return('id' => 556)
      allow(client).to receive(:publish_draft)
      allow(client).to receive(:update_draft) do |id, attrs|
        bodies[id] = JSON.parse(attrs[:draft_body])['content'] if attrs[:draft_body]
      end
      allow(Substack::QuotationEmbed).to receive(:execute).and_return(nil)
    end

    it 'puts the banner before the top pagination nav on page 1' do
      sync
      expect(bodies[555][0]['type']).to eq 'captionedImage'
      expect(bodies[555][1]).to include('type' => 'paragraph', 'attrs' => hash_including('textAlign' => 'center'))
    end

    it "banners page 1 with its first review's cover and title" do
      sync
      banner = bodies[555][0]
      expect(banner['content'].find { |n| n['type'] == 'image2' }['attrs']['src']).to eq 'https://cdn/1.jpg'
      expect(banner['content'].find { |n| n['type'] == 'caption' }['content'][0]['text']).to eq 'First Post'
    end

    it "banners page 2 with its own first review's cover and title" do
      sync
      banner = bodies[556][0]
      expect(banner['content'].find { |n| n['type'] == 'image2' }['attrs']['src']).to eq 'https://cdn/3.jpg'
      expect(banner['content'].find { |n| n['type'] == 'caption' }['content'][0]['text']).to eq 'Third Post'
    end
  end

  context 'with a page-1 intro repeated on every page' do
    let(:bodies) { {} }
    let(:intro)  { { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'People say such wonderful things.' }] } }

    before do
      config.update!(reviews_draft_id: 555, publication_host: 'mikeyclarke.substack.com', reviews_page_size: 2)
      lead = quote(quotation: 'one')
      lead.update!(position: 0)
      quote(quotation: 'two').update!(position: 1)
      quote(quotation: 'three').update!(position: 2)
      existing = { 'type' => 'doc', 'content' => [intro] + Substack::QuotationBlock.build(lead) }
      allow(client).to receive(:get_draft).with(555)
        .and_return('draft_subtitle' => '', 'is_published' => true, 'slug' => 'reviews', 'draft_body' => JSON.generate(existing))
      allow(client).to receive(:get_draft).with(556)
        .and_return('draft_subtitle' => '', 'is_published' => true, 'slug' => 'reviews-page-2')
      allow(client).to receive(:create_draft).and_return('id' => 556)
      allow(client).to receive(:publish_draft)
      allow(client).to receive(:update_draft) do |id, attrs|
        bodies[id] = JSON.parse(attrs[:draft_body])['content'] if attrs[:draft_body]
      end
      allow(Substack::QuotationEmbed).to receive(:execute).and_return(nil)
    end

    it 'keeps the intro on page 1' do
      sync
      expect(bodies[555]).to include(intro)
    end

    it 'repeats the intro on page 2' do
      sync
      expect(bodies[556]).to include(intro)
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

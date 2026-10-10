# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::QuotationsController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET index' do
    before do
      SubstackQuotation.create!(quotation: 'a gem of a blurb', comment_url: 'https://x/comment/1',
                                substack_user: bob, post_title: 'A Post', post_url: 'https://x/p/a')
      get comfy_admin_quotations_path, headers: http_auth_headers
    end

    let(:bob) { create :substack_user, name: 'Bob', handle: 'bob' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'a gem of a blurb' }
    it { expect(response.body).to include 'Bob' }
    it { expect(response.body).to include %(href="#{edit_comfy_admin_substack_user_path(bob)}">Comfy</a>) }
    it { expect(response.body).to include %(href="https://substack.com/@bob">Substack</a>) }
    it { expect(response.body).to_not include %(href="https://substack.com/@bob">Bob</a>) }

    it 'renders the group divider CSS at the configured page size' do
      SubstackSyncConfig.instance.update!(reviews_page_size: 12)
      get comfy_admin_quotations_path, headers: http_auth_headers
      expect(response.body).to include 'nth-child(12n)'
    end

    it 'shows the page-size input prefilled with the configured size' do
      SubstackSyncConfig.instance.update!(reviews_page_size: 12)
      get comfy_admin_quotations_path, headers: http_auth_headers
      expect(response.body).to match(/name="reviews_page_size"[^>]*value="12"/)
    end

    it 'badges a previewable quotation' do
      SubstackQuotation.create!(quotation: 'flagged one', comment_url: 'https://x/comment/2', previewable: true)
      get comfy_admin_quotations_path, headers: http_auth_headers
      expect(response.body).to include 'Previewable'
    end

    it 'does not badge a non-previewable quotation' do
      doc = Nokogiri::HTML(response.body)
      item = doc.at_css('#quotation-sortable li')
      expect(item.text).to_not include 'Previewable'
    end

    it 'shows a thumbnail when post_image_url is present' do
      SubstackQuotation.create!(quotation: 'with an image', comment_url: 'https://x/comment/3',
                                post_image_url: 'https://x/cover.jpg')
      get comfy_admin_quotations_path, headers: http_auth_headers
      expect(response.body).to include 'src="https://x/cover.jpg"'
    end

    it 'shows no thumbnail when post_image_url is blank' do
      doc = Nokogiri::HTML(response.body)
      item = doc.at_css('#quotation-sortable li')
      expect(item.at_css('img')).to be_nil
    end
  end

  describe 'POST create' do
    let(:resolved) do
      Substack::QuotationResolver::Result.new(post_url: 'https://x/p/a', post_title: 'A Post',
                                              author_name: 'Bob', author_handle: 'bob')
    end

    context 'when the comment resolves' do
      before { allow(Substack::QuotationResolver).to receive(:execute).and_return(resolved) }

      it 'creates a record' do
        expect { post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers }
          .to change(SubstackQuotation, :count).by(1)
      end

      it 'stores the resolved post and author' do
        post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers
        expect(SubstackQuotation.last).to have_attributes(quotation: 'blurb', post_title: 'A Post', substack_user: SubstackUser.find_by(name: 'Bob'))
      end

      it 'resolves from the comment url' do
        post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers
        expect(Substack::QuotationResolver).to have_received(:execute).with(comment_url: 'https://x/comment/5', client: nil)
      end

      it 'redirects back' do
        post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers
        expect(response).to redirect_to comfy_admin_quotations_path
      end

      it 'rejects a blank quotation' do
        expect { post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: '' }, headers: http_auth_headers }
          .to_not change(SubstackQuotation, :count)
      end

      it 'does not auto-rebuild the reviews page (manual Rebuild button only)' do
        allow(SyncReviewsPageJob).to receive(:perform_later)
        post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers
        expect(SyncReviewsPageJob).to_not have_received(:perform_later)
      end

      it 'appends the new quotation at the end of the manual order' do
        SubstackQuotation.create!(quotation: 'existing', comment_url: 'https://x/comment/1').update!(position: 7)
        post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers
        expect(SubstackQuotation.find_by(quotation: 'blurb').position).to eq 8
      end
    end

    context 'when resolution fails' do
      before { allow(Substack::QuotationResolver).to receive(:execute).and_raise('bad url') }

      it 'creates no record' do
        expect { post comfy_admin_quotations_path, params: { comment_url: 'bad', quotation: 'blurb' }, headers: http_auth_headers }
          .to_not change(SubstackQuotation, :count)
      end

      it 'redirects back' do
        post comfy_admin_quotations_path, params: { comment_url: 'bad', quotation: 'blurb' }, headers: http_auth_headers
        expect(response).to redirect_to comfy_admin_quotations_path
      end
    end
  end

  describe 'GET edit' do
    let!(:quotation) { SubstackQuotation.create!(quotation: 'old blurb', comment_url: 'https://x/comment/1',
                                                   substack_user: create(:substack_user, name: 'Bob')) }

    before { get comfy_edit_admin_quotation_path(quotation), headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'old blurb' }
    it { expect(response.body).to include 'Update quotation' }
    it { expect(response.body).to include 'name="post_url"' }
    it { expect(response.body).to include 'name="previewable"' }
    it { expect(response.body).to_not include 'name="post_title"' }
    it { expect(response.body).to_not include 'name="post_image_url"' }
  end

  describe 'PATCH update' do
    let!(:quotation) do
      SubstackQuotation.create!(quotation: 'old', comment_url: 'https://x/comment/1',
                                substack_user: create(:substack_user, name: 'Bob'), post_title: 'Old Post')
    end

    context 'editing only the blurb (same comment url)' do
      before { allow(Substack::QuotationResolver).to receive(:execute) }

      it 'updates the text' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'new blurb' }, headers: http_auth_headers
        expect(quotation.reload.quotation).to eq 'new blurb'
      end

      it 'does not re-hit Substack' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'new blurb' }, headers: http_auth_headers
        expect(Substack::QuotationResolver).to_not have_received(:execute)
      end

      it 'keeps the existing metadata' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'new blurb' }, headers: http_auth_headers
        expect(quotation.reload.post_title).to eq 'Old Post'
      end

      it 'does not auto-rebuild the reviews page (manual Rebuild button only)' do
        allow(SyncReviewsPageJob).to receive(:perform_later)
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'new blurb' }, headers: http_auth_headers
        expect(SyncReviewsPageJob).to_not have_received(:perform_later)
      end

      it 'flags the quotation previewable when the checkbox is ticked' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', previewable: '1' }, headers: http_auth_headers
        expect(quotation.reload.previewable).to be true
      end

      it 'unflags previewable when the checkbox is left unticked' do
        quotation.update!(previewable: true)
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old' }, headers: http_auth_headers
        expect(quotation.reload.previewable).to be false
      end
    end

    context 'changing the comment url' do
      let(:resolved) do
        Substack::QuotationResolver::Result.new(post_url: 'https://x/p/b', post_title: 'New Post',
                                                author_name: 'Eva', author_handle: 'eva')
      end

      before { allow(Substack::QuotationResolver).to receive(:execute).and_return(resolved) }

      it 're-resolves the post and author' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/9', quotation: 'old' }, headers: http_auth_headers
        expect(quotation.reload).to have_attributes(comment_url: 'https://x/comment/9', post_title: 'New Post', substack_user: SubstackUser.find_by(name: 'Eva'))
      end

      it 'overrides manually-entered post fields when the comment changes' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/9', quotation: 'old', post_title: 'Manual Post' }, headers: http_auth_headers
        expect(quotation.reload.post_title).to eq 'New Post'
      end
    end

    context 'submitting a post url' do
      let(:metadata) do
        Substack::PostMetadata::Result.new(post_title: 'Fetched Post', post_image_url: 'https://cdn/cover.jpg',
                                           post_id: 55)
      end

      before { allow(Substack::PostMetadata).to receive(:execute).and_return(metadata) }

      it 'stores the post url as submitted' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: 'https://manual/p/z' }, headers: http_auth_headers
        expect(quotation.reload.post_url).to eq 'https://manual/p/z'
      end

      it 'fills the title and image from that post' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: 'https://manual/p/z' }, headers: http_auth_headers
        expect(quotation.reload).to have_attributes(post_title: 'Fetched Post',
                                                     post_image_url: 'https://cdn/cover.jpg', post_id: 55)
      end

      it 'looks the metadata up from the submitted url' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: 'https://manual/p/z' }, headers: http_auth_headers
        expect(Substack::PostMetadata).to have_received(:execute).with(post_url: 'https://manual/p/z', client: nil)
      end

      it 'ignores a hand-posted title' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: 'https://manual/p/z', post_title: 'Typed Title' }, headers: http_auth_headers
        expect(quotation.reload.post_title).to eq 'Fetched Post'
      end
    end

    context 'submitting the publication base URL (no specific post)' do
      before do
        quotation.update!(post_url: 'https://x/p/a', post_title: 'Old Post', post_image_url: 'https://cdn/cover.jpg', post_id: 77)
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: 'https://mikeyclarke.substack.com' }, headers: http_auth_headers
      end

      it { expect(quotation.reload.post_url).to eq 'https://mikeyclarke.substack.com' }
      it { expect(quotation.reload.post_title).to eq 'Sexyverse Advice' }
      it { expect(quotation.reload.post_image_url).to eq Substack::PostMetadata::FALLBACK_IMAGE_URL }
    end

    context 'submitting a blank post url' do
      before do
        quotation.update!(post_url: 'https://x/p/a', post_image_url: 'https://cdn/cover.jpg', post_id: 77)
        allow(Substack::PostMetadata).to receive(:execute)
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: '' }, headers: http_auth_headers
      end

      it { expect(quotation.reload.post_title).to be_nil }
      it { expect(quotation.reload.post_image_url).to be_nil }
      it { expect(Substack::PostMetadata).to_not have_received(:execute) }
    end

    context 'when the post lookup fails' do
      before do
        allow(Substack::PostMetadata).to receive(:execute).and_raise(Substack::Client::Error, 'boom')
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'new blurb', post_url: 'https://manual/p/z' }, headers: http_auth_headers
      end

      it { expect(quotation.reload.quotation).to eq 'old' }
      it { expect(flash[:danger]).to include 'boom' }
    end

    it 'redirects back' do
      allow(Substack::QuotationResolver).to receive(:execute)
      patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'x' }, headers: http_auth_headers
      expect(response).to redirect_to comfy_admin_quotations_path
    end
  end

  describe 'DELETE destroy' do
    let!(:quotation) { SubstackQuotation.create!(quotation: 'x', comment_url: 'https://x/comment/1') }

    it 'deletes the quotation' do
      expect { delete comfy_admin_quotation_path(quotation), headers: http_auth_headers }
        .to change(SubstackQuotation, :count).by(-1)
    end

    it 'does not auto-rebuild the reviews page (manual Rebuild button only)' do
      allow(SyncReviewsPageJob).to receive(:perform_later)
      delete comfy_admin_quotation_path(quotation), headers: http_auth_headers
      expect(SyncReviewsPageJob).to_not have_received(:perform_later)
    end
  end

  describe 'POST sync_reviews' do
    before { allow(SyncReviewsPageJob).to receive(:perform_later) }

    it 'redirects back' do
      post comfy_sync_reviews_admin_quotations_path(page: 3), headers: http_auth_headers
      expect(response).to redirect_to comfy_admin_quotations_path
    end

    it 'enqueues a sync of just that page' do
      post comfy_sync_reviews_admin_quotations_path(page: 3), headers: http_auth_headers
      expect(SyncReviewsPageJob).to have_received(:perform_later).with(3)
    end

    it 'enqueues nothing without a page' do
      post comfy_sync_reviews_admin_quotations_path, headers: http_auth_headers
      expect(SyncReviewsPageJob).to_not have_received(:perform_later)
    end

    it 'does not reshuffle — it mirrors the current manual order' do
      expect(SubstackQuotation).to_not receive(:reorder!)
      post comfy_sync_reviews_admin_quotations_path(page: 3), headers: http_auth_headers
    end
  end

  describe 'GET index Reviews page rows' do
    let(:config) { SubstackSyncConfig.instance }

    def quote(n)
      SubstackQuotation.create!(quotation: "q#{n}", comment_url: "https://x/comment/#{n}", post_url: 'https://x/p/a',
                                post_title: 'A', substack_user: create(:substack_user, name: 'Eva', handle: 'eva'))
    end

    let!(:quotes) { (1..3).map { |n| quote(n) } }

    before do
      config.update!(reviews_page_size: 2, reviews_draft_id: 555, publication_host: 'pub.substack.com',
                     subtitle_variables_json: '{"superlative": ["most kind"]}')
    end

    def rows
      get comfy_admin_quotations_path, headers: http_auth_headers
      Nokogiri::HTML(response.body).css('table tr').map { |tr| tr.text.squish }
    end

    it 'offers a Sync button per page, and no whole-pool rebuild' do
      expect(rows.map { |r| r[/Sync page \d+/] }).to eq ['Sync page 1', 'Sync page 2']
      expect(response.body).to_not include 'Rebuild Reviews Pages'
    end

    it 'links each existing page to its Substack editor' do
      get comfy_admin_quotations_path, headers: http_auth_headers
      expect(response.body).to include 'https://pub.substack.com/publish/post/555'
    end

    it 'marks a page with no draft yet as created on first sync' do
      expect(rows[1]).to include 'Created on first sync'
    end

    it 'marks never-synced pages' do
      expect(rows).to all(include('Not synced yet'))
    end

    context 'after both pages were synced' do
      before do
        groups = config.reviews_page_groups
        groups.each_with_index do |group, i|
          config.record_reviews_page_fingerprint!(i + 1, SubstackQuotation.reviews_page_fingerprint(group, groups.size))
        end
      end

      it 'labels neither' do
        expect(rows.join).to_not match(/Changed|Not synced yet/)
      end

      it 'labels only the page whose quotation was edited' do
        quotes[2].update!(quotation: 'edited')
        expect(rows.map { |r| r.include?('Changed') }).to eq [false, true]
      end

      it 'labels both pages after a reorder across them' do
        SubstackQuotation.reorder!([quotes[2].id, quotes[0].id, quotes[1].id])
        expect(rows.map { |r| r.include?('Changed') }).to eq [true, true]
      end

      it 'labels every page when a new quotation adds a page' do
        quote(4)
        quote(5)
        expect(rows.map { |r| r.include?('Changed') }).to eq [true, true, false]
      end
    end

    context 'with a publish waiting on a manual Update' do
      let(:client) { instance_double(Substack::Client) }
      let(:live) { { 'is_published' => true, 'title' => 'T', 'draft_title' => 'T', 'subtitle' => 's', 'draft_subtitle' => 's', 'body' => '{"a":1}' } }

      before do
        SubstackPendingPublish.create!(draft_id: 555, title: 'Reviews page 1')
        allow(Substack::Client).to receive(:new).and_return(client)
      end

      it 'flags the page while its draft still differs from what is live' do
        allow(client).to receive(:get_draft).with(555).and_return(live.merge('draft_body' => '{"a":2}'))
        expect(rows[0]).to include 'Needs publishing'
      end

      it 'clears the flag once Substack shows the draft published' do
        allow(client).to receive(:get_draft).with(555).and_return(live.merge('draft_body' => '{"a":1}'))
        expect(rows[0]).to_not include 'Needs publishing'
        expect(SubstackPendingPublish.count).to eq 0
      end
    end
  end

  describe 'PUT reorder' do
    let!(:a) { SubstackQuotation.create!(quotation: 'a', comment_url: 'https://x/comment/1') }
    let!(:b) { SubstackQuotation.create!(quotation: 'b', comment_url: 'https://x/comment/2') }

    it 'persists the given order' do
      put comfy_reorder_admin_quotations_path, params: { order: [b.id, a.id] }, headers: http_auth_headers
      expect(SubstackQuotation.by_position.to_a).to eq [b, a]
    end

    it 'responds ok' do
      put comfy_reorder_admin_quotations_path, params: { order: [b.id, a.id] }, headers: http_auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH update_page_size' do
    it 'updates the configured reviews page size' do
      patch comfy_page_size_admin_quotations_path, params: { reviews_page_size: 12 }, headers: http_auth_headers
      expect(SubstackSyncConfig.instance.reviews_page_size).to eq 12
    end

    it 'redirects back with a success flash' do
      patch comfy_page_size_admin_quotations_path, params: { reviews_page_size: 12 }, headers: http_auth_headers
      expect(response).to redirect_to comfy_admin_quotations_path
      expect(flash[:success]).to be_present
    end

    it 'rejects a zero page size' do
      SubstackSyncConfig.instance.update!(reviews_page_size: 20)
      patch comfy_page_size_admin_quotations_path, params: { reviews_page_size: 0 }, headers: http_auth_headers
      expect(SubstackSyncConfig.instance.reload.reviews_page_size).to eq 20
      expect(flash[:danger]).to be_present
    end
  end

  describe 'tracked reposts' do
    let!(:quotation) { SubstackQuotation.create!(quotation: 'zing', comment_url: 'https://x/comment/1') }

    describe 'GET index' do
      context 'with a tracked repost' do
        before do
          quotation.update!(notes: [{ 'url' => 'https://substack.com/@m/note/c-1', 'timestamp' => '2026-06-19T00:00:00Z', 'likes' => 0 }])
          get comfy_admin_quotations_path, headers: http_auth_headers
        end

        it { expect(response.body).to include '1 repost' }
        it { expect(response.body).to include 'href="https://substack.com/@m/note/c-1"' }
      end

      it 'offers a rich copy source and an Add-manually form per quotation' do
        get comfy_admin_quotations_path, headers: http_auth_headers
        expect(response.body).to include 'copy-blizzard-text'
        expect(response.body).to include %(name="quotation_id" id="quotation_id" value="#{quotation.id}")
      end
    end

    # add_note's redirect_back (returning to whichever page the form was on, rather
    # than always /admin/substack-blizzard) is standard Rails behavior driven by the
    # browser's real Referer header — not practically simulable in a request spec,
    # and already precedented unverified elsewhere in this controller (backfill_post).
    describe 'POST add_note' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { quotation_id: quotation.id, url: 'https://substack.com/@m/note/c-2' },
             headers: http_auth_headers
      end

      it { expect(quotation.reload.notes.size).to eq 1 }
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_quotations_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

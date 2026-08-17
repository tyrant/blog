# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::QuotationsController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET index' do
    before do
      SubstackQuotation.create!(quotation: 'a gem of a blurb', comment_url: 'https://x/comment/1',
                                author_name: 'Bob', author_url: 'https://substack.com/@bob',
                                post_title: 'A Post', post_url: 'https://x/p/a')
      get comfy_admin_quotations_path, headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'a gem of a blurb' }
    it { expect(response.body).to include 'Bob' }

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
  end

  describe 'POST create' do
    let(:resolved) do
      Substack::QuotationResolver::Result.new(post_url: 'https://x/p/a', post_title: 'A Post',
                                              author_name: 'Bob', author_url: 'https://substack.com/@bob')
    end

    context 'when the comment resolves' do
      before { allow(Substack::QuotationResolver).to receive(:execute).and_return(resolved) }

      it 'creates a record' do
        expect { post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers }
          .to change(SubstackQuotation, :count).by(1)
      end

      it 'stores the resolved post and author' do
        post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers
        expect(SubstackQuotation.last).to have_attributes(quotation: 'blurb', post_title: 'A Post', author_name: 'Bob')
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

      it 'rebuilds the reviews page' do
        allow(SyncReviewsPageJob).to receive(:perform_later)
        post comfy_admin_quotations_path, params: { comment_url: 'https://x/comment/5', quotation: 'blurb' }, headers: http_auth_headers
        expect(SyncReviewsPageJob).to have_received(:perform_later)
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
    let!(:quotation) { SubstackQuotation.create!(quotation: 'old blurb', comment_url: 'https://x/comment/1', author_name: 'Bob') }

    before { get comfy_edit_admin_quotation_path(quotation), headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'old blurb' }
    it { expect(response.body).to include 'Update quotation' }
    it { expect(response.body).to include 'name="post_url"' }
    it { expect(response.body).to include 'name="post_title"' }
  end

  describe 'PATCH update' do
    let!(:quotation) do
      SubstackQuotation.create!(quotation: 'old', comment_url: 'https://x/comment/1',
                                author_name: 'Bob', post_title: 'Old Post')
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

      it 'rebuilds the reviews page' do
        allow(SyncReviewsPageJob).to receive(:perform_later)
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'new blurb' }, headers: http_auth_headers
        expect(SyncReviewsPageJob).to have_received(:perform_later)
      end

      it 'saves manually-entered post title, url and image' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: 'https://manual/p/z', post_title: 'Manual Post', post_image_url: 'https://manual/cover.jpg' }, headers: http_auth_headers
        expect(quotation.reload).to have_attributes(post_url: 'https://manual/p/z', post_title: 'Manual Post', post_image_url: 'https://manual/cover.jpg')
      end
    end

    context 'changing the comment url' do
      let(:resolved) do
        Substack::QuotationResolver::Result.new(post_url: 'https://x/p/b', post_title: 'New Post',
                                                author_name: 'Eva', author_url: 'https://substack.com/@eva')
      end

      before { allow(Substack::QuotationResolver).to receive(:execute).and_return(resolved) }

      it 're-resolves the post and author' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/9', quotation: 'old' }, headers: http_auth_headers
        expect(quotation.reload).to have_attributes(comment_url: 'https://x/comment/9', post_title: 'New Post', author_name: 'Eva')
      end

      it 'overrides manually-entered post fields when the comment changes' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/9', quotation: 'old', post_title: 'Manual Post' }, headers: http_auth_headers
        expect(quotation.reload.post_title).to eq 'New Post'
      end
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

    it 'rebuilds the reviews page' do
      allow(SyncReviewsPageJob).to receive(:perform_later)
      delete comfy_admin_quotation_path(quotation), headers: http_auth_headers
      expect(SyncReviewsPageJob).to have_received(:perform_later)
    end
  end

  describe 'POST sync_reviews' do
    before { allow(SyncReviewsPageJob).to receive(:perform_later) }

    it 'redirects back' do
      post comfy_sync_reviews_admin_quotations_path, headers: http_auth_headers
      expect(response).to redirect_to comfy_admin_quotations_path
    end

    it 'enqueues the reviews rebuild' do
      post comfy_sync_reviews_admin_quotations_path, headers: http_auth_headers
      expect(SyncReviewsPageJob).to have_received(:perform_later)
    end

    it 'does not reshuffle — it mirrors the current manual order' do
      expect(SubstackQuotation).to_not receive(:reorder!)
      post comfy_sync_reviews_admin_quotations_path, headers: http_auth_headers
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

  describe 'without authentication' do
    before { get comfy_admin_quotations_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

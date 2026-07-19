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

      it 'saves manually-entered post title and url' do
        patch comfy_admin_quotation_path(quotation), params: { comment_url: 'https://x/comment/1', quotation: 'old', post_url: 'https://manual/p/z', post_title: 'Manual Post' }, headers: http_auth_headers
        expect(quotation.reload).to have_attributes(post_url: 'https://manual/p/z', post_title: 'Manual Post')
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
    before do
      allow(SyncReviewsPageJob).to receive(:perform_later)
      post comfy_sync_reviews_admin_quotations_path, headers: http_auth_headers
    end

    it { expect(response).to redirect_to comfy_admin_quotations_path }

    it 'enqueues the reviews rebuild' do
      expect(SyncReviewsPageJob).to have_received(:perform_later)
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_quotations_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

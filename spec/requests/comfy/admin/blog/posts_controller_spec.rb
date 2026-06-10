# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::Blog::PostsController', type: :request do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:blog_post) { create :post, site: site, layout: layout }

  before do
    reset_cms_config
    reset_blog_config
  end

  describe 'GET /admin/sites/:site_id/blog-posts' do
    context 'with authentication' do
      before { 
        get comfy_admin_blog_posts_path(site_id: site.id), headers: http_auth_headers
      }

      it { expect(response).to have_http_status :success }
    end

    context 'without authentication' do
      before { get comfy_admin_blog_posts_path(site_id: site.id) }

      it { expect(response).to have_http_status :unauthorized }
    end
  end

  describe 'GET /admin/sites/:site_id/blog-posts/new' do
    before {
      get new_comfy_admin_blog_post_path(site_id: site.id), headers: http_auth_headers
    }

    it { expect(response).to have_http_status :success }
  end

  describe 'POST /admin/sites/:site_id/blog-posts' do
    let(:valid_params) { { post: { title: 'New Blog Post', slug: 'new-blog-post', layout_id: layout.id, is_published: true } } }

    it {
      expect { post comfy_admin_blog_posts_path(site_id: site.id), params: valid_params, headers: http_auth_headers }
        .to change { Comfy::Blog::Post.count }
        .by 1
    }

    context 'new posts default to unpublished' do
      let(:params_without_is_published) { { post: { title: 'Draft Post', slug: 'draft-post', layout_id: layout.id } } }

      before {
        post comfy_admin_blog_posts_path(site_id: site.id), params: params_without_is_published, headers: http_auth_headers
      }

      it { expect(Comfy::Blog::Post.find_by(slug: 'draft-post').is_published).to be false }
    end
  end

  describe 'GET /admin/sites/:site_id/blog-posts/:id/edit' do
    before {
      get edit_comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), headers: http_auth_headers
    }

    it { expect(response).to have_http_status :success }
  end

  describe 'GET /admin/sites/:site_id/blog-posts/:id/edit (newer/older navigation)' do
    let!(:older_post) { create :post, site: site, layout: layout, title: 'Older Post', slug: 'older', published_at: 3.days.ago }
    let!(:middle_post) { create :post, site: site, layout: layout, title: 'Middle Post', slug: 'middle', published_at: 2.days.ago }
    let!(:newer_post) { create :post, site: site, layout: layout, title: 'Newer Post', slug: 'newer', published_at: 1.day.ago }

    # Just for this block! Only have the three posts above - the other one mucks
    # up the older/newer post title presences/absences.
    before { blog_post.destroy! }

    context 'when viewing the middle post' do
      before {
        get edit_comfy_admin_blog_post_path(site_id: site.id, id: middle_post.id), headers: http_auth_headers
      }

      it { expect(response.body).to include('Newer Post') }
      it { expect(response.body).to include('Older Post') }
    end

    context 'when viewing the newest post' do
      before {
        get edit_comfy_admin_blog_post_path(site_id: site.id, id: newer_post.id), headers: http_auth_headers
      }

      it { expect(response.body).to include('Middle Post') }
      it { expect(response.body).to match(/<div class='newer-post'>\s*<\/div>/m) }
    end

    context 'when viewing the oldest post' do
      before {
        get edit_comfy_admin_blog_post_path(site_id: site.id, id: older_post.id), headers: http_auth_headers
      }

      it { expect(response.body).to include('Middle Post') }
      it { expect(response.body).to match(/<div class='older-post'>\s*<\/div>/m) }
    end
  end

  describe 'PATCH /admin/sites/:site_id/blog-posts/:id' do
    let(:update_params) { { post: { title: 'Updated Post Title' } } }

    before { 
      patch comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), params: update_params, headers: http_auth_headers
    }

    it { expect(blog_post.reload.title).to eq 'Updated Post Title' }
  end

  describe 'PATCH /admin/sites/:site_id/blog-posts/:id (categorizations)' do
    let!(:category) { create :category, site: site, label: 'Medium' }
    let(:update_params) do
      { post: { category_ids: ['', category.id.to_s],
                categorizations_data: { category.id.to_s => { url: 'https://medium.com/x', data: '{"id":"abc"}' } } } }
    end

    before {
      patch comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), params: update_params, headers: http_auth_headers
    }

    it { expect(blog_post.categorizations.first.url).to eq 'https://medium.com/x' }
    it { expect(blog_post.categorizations.first.data).to eq({ 'id' => 'abc' }) }
  end

  describe 'GET edit renders categorization fields' do
    let!(:category) { create :category, site: site, label: 'Medium' }
    let!(:categorization) { create :categorization, category: category, categorized: blog_post, url: 'https://medium.com/y' }

    before {
      get edit_comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), headers: http_auth_headers
    }

    it { expect(response.body).to include 'https://medium.com/y' }
    it { expect(response.body).to include 'categorizations_data' }
  end

  describe 'PATCH /admin/sites/:site_id/blog-posts/:id.json (autosave)' do
    let(:update_params) { { post: { title: 'Autosaved Title' } } }
    let(:json_headers) { http_auth_headers.merge('Accept' => 'application/json') }

    context 'with valid params' do
      before {
        patch "#{comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id)}.json",
              params: update_params,
              headers: json_headers
      }

      it { expect(response).to have_http_status :success }
      it { expect(response.content_type).to include 'application/json' }
      it { expect(JSON.parse(response.body)['success']).to be true }
      it { expect(JSON.parse(response.body)['updated_at']).to be_present }
      it { expect(blog_post.reload.title).to eq 'Autosaved Title' }
    end

    context 'with invalid params' do
      let(:invalid_params) { { post: { title: '', slug: '' } } }

      before {
        patch "#{comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id)}.json",
              params: invalid_params,
              headers: json_headers
      }

      it { expect(response).to have_http_status :unprocessable_entity }
      it { expect(JSON.parse(response.body)['success']).to be false }
      it { expect(JSON.parse(response.body)['error']).to be_present }
    end
  end

  describe 'DELETE /admin/sites/:site_id/blog-posts/:id' do
    it {
      expect { delete comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), headers: http_auth_headers }
        .to change { Comfy::Blog::Post.count }
        .by -1
    }
  end

  describe 'POST /admin/sites/:site_id/blog-posts/:id/sync-to-medium' do
    context 'with authentication' do
      context 'when the sync succeeds' do
        before do
          allow(Medium::PostSyncer).to receive(:execute)
          post sync_to_medium_comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id),
               headers: http_auth_headers
        end

        it { expect(response).to have_http_status :success }

        it 'returns JSON with success: true' do
          expect(JSON.parse(response.body)['success']).to be true
        end

        it 'calls PostSyncer with the post id' do
          expect(Medium::PostSyncer).to have_received(:execute).with(post_id: blog_post.id)
        end
      end

      context 'when the sync raises an error' do
        before do
          allow(Medium::PostSyncer).to receive(:execute).and_raise('browser crashed')
          post sync_to_medium_comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id),
               headers: http_auth_headers
        end

        it { expect(response).to have_http_status :unprocessable_entity }

        it 'returns JSON with success: false' do
          expect(JSON.parse(response.body)['success']).to be false
        end

        it 'returns the error message in JSON' do
          expect(JSON.parse(response.body)['message']).to eq 'browser crashed'
        end
      end
    end

    context 'without authentication' do
      before do
        post sync_to_medium_comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id)
      end

      it { expect(response).to have_http_status :unauthorized }
    end
  end
end

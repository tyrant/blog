# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::Blog::PostsController', type: :request do
  let!(:site) { create(:site) }
  let!(:layout) { create(:layout, site: site) }
  let!(:post) { create(:post, site: site, layout: layout) }

  before do
    reset_cms_config
    reset_blog_config
  end

  describe 'GET /admin/sites/:site_id/blog-posts' do
    it 'returns success with authentication' do
      get comfy_admin_blog_posts_path(site_id: site.id), headers: http_auth_headers
      expect(response).to have_http_status(:success)
    end

    it 'requires authentication' do
      get comfy_admin_blog_posts_path(site_id: site.id)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /admin/sites/:site_id/blog-posts/new' do
    it 'returns success' do
      get new_comfy_admin_blog_post_path(site_id: site.id), headers: http_auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /admin/sites/:site_id/blog-posts' do
    let(:valid_params) do
      {
        post: {
          title: 'New Blog Post',
          slug: 'new-blog-post',
          layout_id: layout.id,
          is_published: true
        }
      }
    end

    it 'creates a new post' do
      expect {
        post comfy_admin_blog_posts_path(site_id: site.id), params: valid_params, headers: http_auth_headers
      }.to change { Comfy::Blog::Post.count }.by(1)
    end
  end

  describe 'GET /admin/sites/:site_id/blog-posts/:id/edit' do
    it 'returns success' do
      get edit_comfy_admin_blog_post_path(site_id: site.id, id: post.id), headers: http_auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /admin/sites/:site_id/blog-posts/:id' do
    let(:update_params) do
      { post: { title: 'Updated Post Title' } }
    end

    it 'updates the post' do
      patch comfy_admin_blog_post_path(site_id: site.id, id: post.id), params: update_params, headers: http_auth_headers
      expect(post.reload.title).to eq('Updated Post Title')
    end
  end

  describe 'DELETE /admin/sites/:site_id/blog-posts/:id' do
    it 'destroys the post' do
      expect {
        delete comfy_admin_blog_post_path(site_id: site.id, id: post.id), headers: http_auth_headers
      }.to change { Comfy::Blog::Post.count }.by(-1)
    end
  end
end

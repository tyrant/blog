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
  end

  describe 'GET /admin/sites/:site_id/blog-posts/:id/edit' do
    before {
      get edit_comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), headers: http_auth_headers
    }

    it { expect(response).to have_http_status :success }
  end

  describe 'PATCH /admin/sites/:site_id/blog-posts/:id' do
    let(:update_params) { { post: { title: 'Updated Post Title' } } }

    before { 
      patch comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), params: update_params, headers: http_auth_headers
    }

    it { expect(blog_post.reload.title).to eq 'Updated Post Title' }
  end

  describe 'DELETE /admin/sites/:site_id/blog-posts/:id' do
    it { 
      expect { delete comfy_admin_blog_post_path(site_id: site.id, id: blog_post.id), headers: http_auth_headers }
        .to change { Comfy::Blog::Post.count }
        .by -1
    }
  end
end

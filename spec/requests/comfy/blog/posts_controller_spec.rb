# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Blog::PostsController', type: :request do
  let!(:site) { create(:site, hostname: 'test.host') }
  let!(:layout) { create(:layout, site: site) }
  let!(:published_post) { create(:post, site: site, layout: layout, is_published: true, published_at: Time.current) }
  let!(:unpublished_post) { create(:post, site: site, layout: layout, is_published: false) }

  before do
    reset_cms_config
    reset_blog_config
    host! site.hostname
  end

  describe 'GET /blog' do
    it 'returns success' do
      get '/blog'
      expect(response).to have_http_status(:success)
    end

    it 'shows published posts' do
      get '/blog'
      expect(response.body).to include(published_post.title)
    end

    it 'does not show unpublished posts' do
      get '/blog'
      expect(response.body).not_to include(unpublished_post.title)
    end
  end

  describe 'GET /blog/:year' do
    it 'returns success' do
      get "/blog/#{published_post.year}"
      expect(response).to have_http_status(:success)
    end

    it 'filters posts by year' do
      get "/blog/#{published_post.year}"
      expect(response.body).to include(published_post.title)
    end
  end

  describe 'GET /blog/:year/:month' do
    it 'returns success' do
      get "/blog/#{published_post.year}/#{published_post.month}"
      expect(response).to have_http_status(:success)
    end

    it 'filters posts by year and month' do
      get "/blog/#{published_post.year}/#{published_post.month}"
      expect(response.body).to include(published_post.title)
    end
  end

  describe 'GET /blog/:year/:month/:slug' do
    it 'returns success for published post' do
      get "/blog/#{published_post.year}/#{published_post.month}/#{published_post.slug}"
      expect(response).to have_http_status(:success)
    end

    it 'shows post content' do
      get "/blog/#{published_post.year}/#{published_post.month}/#{published_post.slug}"
      expect(response.body).to include(published_post.title)
    end

    it 'returns 404 for unpublished post' do
      expect {
        get "/blog/#{unpublished_post.year}/#{unpublished_post.month}/#{unpublished_post.slug}"
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

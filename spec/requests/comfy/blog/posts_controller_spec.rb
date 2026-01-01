# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Blog::PostsController', type: :request do
  let!(:site) { create :site, hostname: 'test.host' }
  let!(:layout) { create :layout, site: site }
  let!(:published_post) { create :post, site: site, layout: layout, is_published: true, published_at: Time.current }
  let!(:unpublished_post) { create :post, site: site, layout: layout, is_published: false }

  before do
    reset_cms_config
    reset_blog_config
    host! site.hostname
  end

  describe 'GET /blog' do
    before { get '/blog' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to_not include unpublished_post.title }
  end

  describe 'GET /blog/:year' do
    before { get "/blog/#{published_post.year}" }

    it { expect(response).to have_http_status :success }
  end

  describe 'GET /blog/:year/:month' do
    before { get "/blog/#{published_post.year}/#{published_post.month}" }

    it { expect(response).to have_http_status :success }
  end

  describe 'GET /blog/:year/:month/:slug' do
    context 'for published post' do
      before { get "/blog/#{published_post.year}/#{published_post.month}/#{published_post.slug}" }

      it { expect(response).to have_http_status :success }
    end

    context 'for unpublished post' do
      it { 
        expect { get "/blog/#{unpublished_post.year}/#{unpublished_post.month}/#{unpublished_post.slug}" }
          .to raise_error ComfortableMexicanSofa::MissingPage
      }
    end
  end
end

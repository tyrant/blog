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

    context 'for stale slug (post slug changed)', versioning: true do
      let(:old_slug) { 'old-post-slug' }
      let(:new_slug) { 'new-post-slug' }
      let!(:stale_post) do
        p = create :post, site: site, layout: layout, is_published: true,
                          published_at: Time.current, custom_slug: old_slug
        p.update!(slug: new_slug)
        p
      end

      before { get "/blog/#{stale_post.year}/#{stale_post.month}/#{old_slug}" }

      it { expect(response).to have_http_status :redirect }
      it { expect(response).to redirect_to "/blog/#{stale_post.year}/#{stale_post.month}/#{new_slug}" }
    end

    context 'for stale slug with multiple history entries', versioning: true do
      let!(:stale_post) do
        p = create :post, site: site, layout: layout, is_published: true,
                          published_at: Time.current, custom_slug: 'first-slug'
        p.update!(slug: 'second-slug')
        p.update!(slug: 'final-slug')
        p
      end

      before { get "/blog/#{stale_post.year}/#{stale_post.month}/second-slug" }

      it { expect(response).to redirect_to "/blog/#{stale_post.year}/#{stale_post.month}/final-slug" }
    end

    context 'for completely unknown slug' do
      it { expect { get '/blog/2026/1/nonexistent-slug' }.to raise_error ComfortableMexicanSofa::MissingPage }
    end

    context 'for stale slug of unpublished post', versioning: true do
      let!(:unpub_post) do
        p = create :post, site: site, layout: layout, is_published: false, custom_slug: 'old-unpub'
        p.update!(slug: 'new-unpub')
        p
      end

      it { expect { get "/blog/#{unpub_post.year}/#{unpub_post.month}/old-unpub" }.to raise_error ComfortableMexicanSofa::MissingPage }
    end
  end
end

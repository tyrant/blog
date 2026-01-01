# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PostsController', type: :request do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:category1) { create :category, label: 'Shite Advice', site: site }
  let!(:category2) { create :category, label: 'Whimsy', site: site }
  let!(:nsfw_category) { create :category, label: 'NSFW', site: site }
  let!(:post1) { create :post, site: site, layout: layout, published_at: 2.days.ago }
  let!(:post2) { create :post, site: site, layout: layout, published_at: 1.day.ago }
  let!(:post3) { create :post, site: site, layout: layout, published_at: Time.current }

  before do
    allow_any_instance_of(PostsController).to receive(:load_cms_site) do |controller|
      controller.instance_variable_set(:@cms_site, site)
    end
    allow(site).to receive(:blog_posts).and_return(Comfy::Blog::Post.where(site: site))
  end

  describe 'GET /blog' do
    before { get '/blog' }

    it { expect(response).to have_http_status :success }

    context 'with category filter' do
      let!(:categorization) { create :categorization, category: category1, categorized: post1 }

      before { get '/blog', params: { category: category1.label } }

      it { expect(response).to have_http_status :success }
    end

    context 'with year filter' do
      before { get '/blog', params: { year: Time.current.year } }

      it { expect(response).to have_http_status :success }
    end

    context 'with year and month filter' do
      before { get '/blog', params: { year: Time.current.year, month: Time.current.month } }

      it { expect(response).to have_http_status :success }
    end
  end

  describe 'GET /posts/:id/prev_nek' do
    let!(:categorization1) { create :categorization, category: category1, categorized: post1 }
    let!(:categorization2) { create :categorization, category: category2, categorized: post2 }

    before { get "/posts/#{post1.id}/prev_nek" }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include category1.label }
    it { expect(response.body).to include category2.label }

    context 'with NSFW banish setting' do
      before { get "/posts/#{post1.id}/prev_nek", headers: { 'Cookie' => 'banish_nsfw_completely=true' } }

      it { expect(response).to have_http_status :success }
    end

    context 'when post does not exist' do
      before { get '/posts/999999/prev_nek' }

      it { expect(response).to have_http_status :not_found }
    end
  end

  describe 'NSFW filtering integration' do
    let!(:nsfw_post) { create :post, site: site, layout: layout }
    let!(:nsfw_categorization) { create :categorization, category: nsfw_category, categorized: nsfw_post }

    context 'with banish false' do
      before { get '/blog', headers: { 'Cookie' => 'banish_nsfw_completely=false' } }

      it { expect(response).to have_http_status :success }
    end

    context 'with banish true' do
      before { get '/blog', headers: { 'Cookie' => 'banish_nsfw_completely=true' } }

      it { expect(response).to have_http_status :success }
    end
  end

  describe 'pagination' do
    before do
      10.times { |i| create :post, site: site, layout: layout, published_at: i.days.ago }
      get '/blog'
    end

    it { expect(response).to have_http_status :success }
  end
end

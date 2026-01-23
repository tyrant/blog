# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Blog::Post, type: :model do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }

  let(:scratchpad) { '' }
  let!(:post) { create :post, site: site, layout: layout, scratchpad: scratchpad }

  before do
    reset_cms_config
    reset_blog_config
  end

  describe 'associations' do
    it { is_expected.to belong_to(:site).class_name('Comfy::Cms::Site') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:slug) }

    context 'year and month presence' do
      let(:new_post) { Comfy::Blog::Post.new(title: 'Test', slug: 'test', site: site) }

      before { new_post.valid? }

      it { expect(new_post.year).to be_present }
      it { expect(new_post.month).to be_present }
    end
  end

  describe 'slug uniqueness validation' do
    context 'when same year and month' do
      let!(:existing) { create :post, site: site, layout: layout, slug: 'unique-slug-test', published_at: Time.current }
      let(:duplicate) do
        Comfy::Blog::Post.new(
          site: site, layout: layout, title: 'Duplicate',
          slug: existing.slug, year: existing.year, month: existing.month
        )
      end

      it { expect(duplicate).to_not be_valid }
      it { expect(duplicate.tap(&:valid?).errors[:slug]).to be_present }
    end

    context 'when different year' do
      let!(:old_post) { create :post, site: site, layout: layout, published_at: 1.year.ago }
      let(:new_post) { build :post, site: site, layout: layout, slug: old_post.slug, published_at: Time.current }

      it { expect(new_post).to be_valid }
    end
  end

  describe 'automatic slug assignment' do
    let(:new_post) { Comfy::Blog::Post.new(title: 'Test Post Title', site: site, layout: layout) }

    before { new_post.valid? }

    it { expect(new_post.slug).to eq 'test-post-title' }
  end

  describe 'automatic date assignment' do
    let(:new_post) { create :post, site: site, layout: layout, published_at: nil }

    it { expect(new_post.published_at).to be_present }
    it { expect(new_post.year).to eq new_post.published_at.year }
    it { expect(new_post.month).to eq new_post.published_at.month }
  end

  describe 'scopes' do
    describe '.published' do
      let!(:published_post) { create :post, site: site, layout: layout, is_published: true }
      let!(:unpublished_post) { create :post, site: site, layout: layout, is_published: false }

      it { expect(Comfy::Blog::Post.published).to include published_post }
      it { expect(Comfy::Blog::Post.published).to_not include unpublished_post }
    end

    describe '.for_year' do
      let!(:post_2023) { create :post, site: site, layout: layout, published_at: Date.new(2023, 6, 15) }
      let!(:post_2024) { create :post, site: site, layout: layout, published_at: Date.new(2024, 6, 15) }

      it { expect(Comfy::Blog::Post.for_year(2023)).to include post_2023 }
      it { expect(Comfy::Blog::Post.for_year(2023)).to_not include post_2024 }
    end

    describe '.for_month' do
      let!(:jan_post) { create :post, site: site, layout: layout, published_at: Date.new(2024, 1, 15) }
      let!(:feb_post) { create :post, site: site, layout: layout, published_at: Date.new(2024, 2, 15) }

      it { expect(Comfy::Blog::Post.for_month(1)).to include jan_post }
      it { expect(Comfy::Blog::Post.for_month(1)).to_not include feb_post }
    end
  end

  describe '#url' do
    it { expect(post.url).to include "//#{site.hostname}" }
    it { expect(post.url).to include "/blog/#{post.year}/#{post.month}/#{post.slug}" }
    it { expect(post.url(relative: true)).to start_with '/blog/' }

    context 'with custom blog path' do
      before { ComfyBlog.config.public_blog_path = 'test-blog' }

      it { expect(post.url).to include '/test-blog/' }
    end
  end

  describe '#is_published?' do
    context 'when published' do
      before { post.update(is_published: true) }

      it { expect(post.is_published?).to be true }
    end

    context 'when not published' do
      before { post.update(is_published: false) }

      it { expect(post.is_published?).to be false }
    end
  end

  describe '#socials_url_for' do

    let(:platform) { 'medium' }
    subject { post.socials_url_for(platform: platform) }

    context "Post has zero categories" do
      it { is_expected.to eq '' }
    end

    context "Post has categories" do
          
      let!(:category) { create :category, label: platform.capitalize }
      let!(:categorization) { create :categorization,
                                    category: category,
                                    categorized: post }

      context "Post's category list doesn't include :platform" do
        let(:platform) { 'twitter' }
        it { is_expected.to eq '' }
      end

      context "Post's category list includes :platform" do

        context "#scratchpad doesn't include a URL for :platform" do
          it { is_expected.to eq '' }
        end

        context "#scratchpad contains corresponding URL" do
          let(:scratchpad) { "\r\nhttps://medium.com/@pi_neutrino\r\nblargh\r\nblargh again\r\n" }
          it { is_expected.to eq 'https://medium.com/@pi_neutrino' }
        end
      end
    end

  end
end

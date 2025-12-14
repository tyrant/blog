# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Blog::Post, type: :model do
  let!(:site) { create(:site) }
  let!(:layout) { create(:layout, site: site) }
  let!(:post) { create(:post, site: site, layout: layout) }

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

    it 'validates year and month presence' do
      # Year and month are set by callbacks from published_at
      new_post = Comfy::Blog::Post.new(title: 'Test', slug: 'test', site: site)
      new_post.valid?
      expect(new_post.year).to be_present
      expect(new_post.month).to be_present
    end
  end

  describe 'slug uniqueness validation' do
    context 'when same year and month' do
      it 'requires unique slug within same site, year and month' do
        existing = create(:post, site: site, layout: layout, slug: 'unique-slug-test', published_at: Time.current)
        duplicate = Comfy::Blog::Post.new(
          site: site, layout: layout, title: 'Duplicate',
          slug: existing.slug, year: existing.year, month: existing.month
        )
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:slug]).to be_present
      end
    end

    context 'when different year' do
      let!(:old_post) { create(:post, site: site, layout: layout, published_at: 1.year.ago) }

      it 'allows same slug in different year' do
        new_post = build(:post, site: site, layout: layout, slug: old_post.slug, published_at: Time.current)
        expect(new_post).to be_valid
      end
    end
  end

  describe 'automatic slug assignment' do
    it 'assigns slug from title when nil' do
      new_post = Comfy::Blog::Post.new(title: 'Test Post Title', site: site, layout: layout)
      new_post.valid?
      expect(new_post.slug).to eq('test-post-title')
    end
  end

  describe 'automatic date assignment' do
    let(:new_post) { create(:post, site: site, layout: layout, published_at: nil) }

    it 'sets published_at to current time' do
      expect(new_post.published_at).to be_present
    end

    it 'sets year from published_at' do
      expect(new_post.year).to eq(new_post.published_at.year)
    end

    it 'sets month from published_at' do
      expect(new_post.month).to eq(new_post.published_at.month)
    end
  end

  describe 'scopes' do
    describe '.published' do
      let!(:published_post) { create(:post, site: site, layout: layout, is_published: true) }
      let!(:unpublished_post) { create(:post, site: site, layout: layout, is_published: false) }

      it 'returns only published posts' do
        expect(Comfy::Blog::Post.published).to include(published_post)
        expect(Comfy::Blog::Post.published).not_to include(unpublished_post)
      end
    end

    describe '.for_year' do
      let!(:post_2023) { create(:post, site: site, layout: layout, published_at: Date.new(2023, 6, 15)) }
      let!(:post_2024) { create(:post, site: site, layout: layout, published_at: Date.new(2024, 6, 15)) }

      it 'filters by year' do
        expect(Comfy::Blog::Post.for_year(2023)).to include(post_2023)
        expect(Comfy::Blog::Post.for_year(2023)).not_to include(post_2024)
      end
    end

    describe '.for_month' do
      let!(:jan_post) { create(:post, site: site, layout: layout, published_at: Date.new(2024, 1, 15)) }
      let!(:feb_post) { create(:post, site: site, layout: layout, published_at: Date.new(2024, 2, 15)) }

      it 'filters by month' do
        expect(Comfy::Blog::Post.for_month(1)).to include(jan_post)
        expect(Comfy::Blog::Post.for_month(1)).not_to include(feb_post)
      end
    end
  end

  describe '#url' do
    it 'returns protocol-relative URL' do
      expect(post.url).to include("//#{site.hostname}")
      expect(post.url).to include("/blog/#{post.year}/#{post.month}/#{post.slug}")
    end

    it 'returns relative URL when requested' do
      expect(post.url(relative: true)).to start_with('/blog/')
    end

    context 'with custom blog path' do
      before { ComfyBlog.config.public_blog_path = 'test-blog' }

      it 'uses custom path' do
        expect(post.url).to include('/test-blog/')
      end
    end
  end

  describe '#is_published?' do
    it 'returns true when published' do
      post.update(is_published: true)
      expect(post.is_published?).to be true
    end

    it 'returns false when not published' do
      post.update(is_published: false)
      expect(post.is_published?).to be false
    end
  end
end

require 'rails_helper'

RSpec.describe PostComponent, type: :component do
  include ViewComponent::TestHelpers
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:category1) { create :category, label: 'Whimsy', site: site }
  let!(:category2) { create :category, label: 'NSFW', site: site }
  let!(:post) { create :post, site: site, layout: layout, published_at: 1.day.ago }
  let!(:nsfw_post) { create :post, site: site, layout: layout, published_at: 1.day.ago }
  let!(:categorization1) { create :categorization, category: category1, categorized: post }
  let!(:categorization2) { create :categorization, category: category2, categorized: nsfw_post }

  let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => false, 'always' => false } }

  describe '#initialize' do
    it 'accepts required parameters' do
      component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
      expect(component).to be_present
    end
  end

  describe 'rendering' do
    it 'renders the post component' do
      render_inline(PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options))
      expect(rendered_component).to be_present
    end

    it 'includes post title (truncated)' do
      render_inline(PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options))
      expect(rendered_component).to include(post.title.truncate(72, separator: ' ', omission: ' ...'))
    end

    it 'includes post link' do
      render_inline(PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options))
      expected_path = "/blog/#{post.year}/#{post.month}/#{post.slug}"
      expect(rendered_component).to include(expected_path)
    end
  end

  describe 'CSS classes' do
    context 'for regular posts' do
      it 'includes base CSS classes' do
        component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
        css_classes = component.send(:css_classes)
        expect(css_classes).to include('post', 'transition', 'bg-white', 'dark:bg-gray-800')
        expect(css_classes).to include('duration-150')
      end

      it 'does not include hidden classes for non-NSFW posts' do
        component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
        css_classes = component.send(:css_classes)
        expect(css_classes).not_to include('hidden', 'opacity-0')
      end
    end

    context 'for NSFW posts' do
      it 'includes hidden classes when banish is true' do
        nsfw_options = default_nsfw_options.merge('banish' => true)
        component = PostComponent.new(post: nsfw_post, cms_site: site, nsfw_options: nsfw_options)
        css_classes = component.send(:css_classes)
        expect(css_classes).to include('hidden', 'opacity-0')
      end

      it 'includes blur classes for body when not always visible' do
        component = PostComponent.new(post: nsfw_post, cms_site: site, nsfw_options: default_nsfw_options)
        body_classes = component.send(:css_classes_for_body)
        expect(body_classes).to include('blur-sm')
      end

      it 'does not include blur classes when always visible' do
        nsfw_options = default_nsfw_options.merge('always' => true, 'mouseover' => true)
        component = PostComponent.new(post: nsfw_post, cms_site: site, nsfw_options: nsfw_options)
        body_classes = component.send(:css_classes_for_body)
        expect(body_classes).not_to include('blur-sm')
      end
    end
  end

  describe 'category CSS classes' do
    it 'applies correct CSS for Whimsy category' do
      component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
      category_classes = component.send(:css_classes_for_category, category1)
      expect(category_classes).to include('bg-indigo-100', 'text-indigo-800', 'cat-blurrable')
    end

    it 'applies correct CSS for NSFW category' do
      component = PostComponent.new(post: nsfw_post, cms_site: site, nsfw_options: default_nsfw_options)
      category_classes = component.send(:css_classes_for_category, category2)
      expect(category_classes).to include('bg-red-800', 'text-red-100')
    end

    it 'applies blur to non-NSFW categories on NSFW posts when not always visible' do
      component = PostComponent.new(post: nsfw_post, cms_site: site, nsfw_options: default_nsfw_options)
      category_classes = component.send(:css_classes_for_category, category1)
      expect(category_classes).to include('blur-sm')
    end
  end

  describe 'content processing' do
    it 'truncates post content' do
      component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
      content = component.send(:post_content)
      expect(content.length).to be <= 120
    end

    it 'processes HTML content and converts to text' do
      # Use the actual content_cache from the post factory instead of updating
      component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
      content = component.send(:post_content)
      expect(content).to be_a(String)
      expect(content.length).to be <= 120
      # Content should not contain HTML tags
      expect(content).not_to include('<', '>')
    end
  end

  describe 'image handling' do
    it 'calls resized_blob_or_orig_or_placeholder_url on post' do
      expect(post).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/image.jpg')
      component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
      expect(component.send(:post_image_path)).to eq('/test/image.jpg')
    end

    it 'caches the image path' do
      allow(post).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/image.jpg')
      component = PostComponent.new(post: post, cms_site: site, nsfw_options: default_nsfw_options)
      
      # Call twice to test caching
      path1 = component.send(:post_image_path)
      path2 = component.send(:post_image_path)
      
      expect(path1).to eq(path2)
      expect(post).to have_received(:resized_blob_or_orig_or_placeholder_url).once
    end
  end
end

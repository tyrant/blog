# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostComponent, type: :component do
  include ViewComponent::TestHelpers
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:category1) { Tag.create!(name: 'Whimsy') }
  let!(:category2) { Tag.create!(name: 'NSFW') }
  let!(:post) { create :post, site: site, layout: layout, published_at: 1.day.ago }
  let!(:nsfw_post) { create :post, site: site, layout: layout, published_at: 1.day.ago }
  let!(:categorization1) { BlogPostTag.without_mirror { post.tags << category1 } }
  let!(:categorization2) { BlogPostTag.without_mirror { nsfw_post.tags << category2 } }

  let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => false, 'always' => false } }
  subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options }

  describe '#initialize' do
    it { is_expected.to be_present }
  end

  describe 'rendering' do
    let(:expected_path) { "/blog/#{post.year}/#{post.month}/#{post.slug}" }
    let(:truncated_title) { CGI.escapeHTML(post.title.truncate(100, separator: ' ', omission: ' ...')) }
    
    before { render_inline(subject) }
    it { expect(rendered_content).to be_present }
    it { expect(rendered_content).to include(truncated_title) }
    it { expect(rendered_content).to include(expected_path) }
  end

  describe 'CSS classes' do
    let(:css_classes) { subject.send(:css_classes) }
    
    context 'for regular posts' do
      it { expect(css_classes).to include('post', 'transition', 'bg-white', 'dark:bg-gray-800') }
      it { expect(css_classes).to include('duration-150') }
      it { expect(css_classes).not_to include('hidden', 'opacity-0') }
    end

    context 'for NSFW posts' do
      subject { PostComponent.new post: nsfw_post, cms_site: site, nsfw_options: default_nsfw_options }
      
      context 'when banish is true' do
        let(:default_nsfw_options) { { 'banish' => true, 'mouseover' => false, 'always' => false } }
        it { expect(css_classes).to include('hidden', 'opacity-0') }
      end

      context 'when not always visible' do
        let(:body_classes) { subject.send(:css_classes_for_body) }
        it { expect(body_classes).to include('blur-xs') }
      end

      context 'when always visible' do
        let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => true, 'always' => true } }
        let(:body_classes) { subject.send(:css_classes_for_body) }
        it { expect(body_classes).not_to include('blur-xs') }
      end
    end
  end

  describe 'category CSS classes' do
    context 'for Whimsy category' do
      let(:category_classes) { subject.send(:css_classes_for_category, category1) }
      it { expect(category_classes).to include('bg-indigo-100', 'text-indigo-800', 'cat-blurrable') }
    end

    context 'for NSFW category' do
      subject { PostComponent.new post: nsfw_post, cms_site: site, nsfw_options: default_nsfw_options }
      let(:category_classes) { subject.send(:css_classes_for_category, category2) }
      it { expect(category_classes).to include('bg-red-800', 'text-red-100') }
    end

    context 'for non-NSFW categories on NSFW posts' do
      subject { PostComponent.new post: nsfw_post, cms_site: site, nsfw_options: default_nsfw_options }
      let(:category_classes) { subject.send(:css_classes_for_category, category1) }
      it { expect(category_classes).to include('blur-xs') }
    end
  end

  describe 'content processing' do
    let(:content) { subject.send(:post_content) }
    
    it { expect(content.length).to be <= 120 }
    it { expect(content).to be_a(String) }
    it { expect(content).not_to include('<', '>') }
  end

  describe 'image handling' do
    context 'when calling post_image_path' do
      before { expect(post).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/image.jpg') }
      it { expect(subject.send(:post_image_path)).to eq('/test/image.jpg') }
    end

    context 'when caching image path' do
      before do
        allow(post).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/image.jpg')
        # Call twice to test caching
        subject.send(:post_image_path)
        subject.send(:post_image_path)
      end
      it { expect(post).to have_received(:resized_blob_or_orig_or_placeholder_url).once }
    end
  end

  describe 'show_text parameter' do
    context 'when show_text is not provided (default)' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options }
      
      it 'defaults to true' do
        expect(subject.instance_variable_get(:@show_text)).to eq(true)
      end
    end

    context 'when show_text is explicitly true' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: true }
      
      it 'sets show_text to true' do
        expect(subject.instance_variable_get(:@show_text)).to eq(true)
      end
    end

    context 'when show_text is false' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: false }
      
      it 'sets show_text to false' do
        expect(subject.instance_variable_get(:@show_text)).to eq(false)
      end
    end
  end

  describe '#css_classes_for_image' do
    context 'when show_text is true (default)' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: true }
      let(:image_classes) { subject.send(:css_classes_for_image) }

      it 'includes base image classes' do
        expect(image_classes).to include('object-cover', 'w-full', 'h-64', 'shadow-lg', 'scale-100', 'ease-in', 'duration-150')
      end

      it 'includes rounded-t-xl for top corners only' do
        expect(image_classes).to include('rounded-t-xl')
      end

      it 'does not include rounded-xl for all corners' do
        expect(image_classes).not_to include('rounded-xl')
      end
    end

    context 'when show_text is false' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: false }
      let(:image_classes) { subject.send(:css_classes_for_image) }

      it 'includes base image classes' do
        expect(image_classes).to include('object-cover', 'w-full', 'h-64', 'shadow-lg', 'scale-100', 'ease-in', 'duration-150')
      end

      it 'includes rounded-xl for all corners' do
        expect(image_classes).to include('rounded-xl')
      end

      it 'does not include rounded-t-xl' do
        expect(image_classes).not_to include('rounded-t-xl')
      end
    end
  end

  describe '#css_classes_for_titlebg' do
    context 'when show_text is true' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: true }
      let(:titlebg_classes) { subject.send(:css_classes_for_titlebg) }

      it 'includes base title background classes' do
        expect(titlebg_classes).to include('w-full', 'h-28', 'bg-gradient-to-b', 'from-transparent', 'to-60%', 'to-neutral-800/75', 'absolute', 'top-36', 'left-0')
      end

      it 'does not include rounded-b-xl' do
        expect(titlebg_classes).not_to include('rounded-b-xl')
      end
    end

    context 'when show_text is false' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: false }
      let(:titlebg_classes) { subject.send(:css_classes_for_titlebg) }

      it 'includes base title background classes' do
        expect(titlebg_classes).to include('w-full', 'h-28', 'bg-gradient-to-b', 'from-transparent', 'to-60%', 'to-neutral-800/75', 'absolute', 'top-36', 'left-0')
      end

      it 'includes rounded-b-xl for bottom corners' do
        expect(titlebg_classes).to include('rounded-b-xl')
      end
    end
  end

  describe 'rendering with show_text' do
    let(:truncated_content) { subject.send(:post_content) }

    context 'when show_text is true (default)' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: true }
      
      before { render_inline(subject) }

      it 'renders the text preview' do
        expect(rendered_content).to include('text-sm text-gray-600 dark:text-gray-300')
      end

      it 'includes the post content text' do
        expect(rendered_content).to include(CGI.escapeHTML(truncated_content))
      end

      it 'uses rounded-t-xl on image' do
        expect(rendered_content).to include('rounded-t-xl')
      end

      it 'does not use rounded-xl on image' do
        # Should not have rounded-xl in the image tag context
        expect(rendered_content.scan(/rounded-xl/).count).to eq(1) # Only on the outer post div
      end
    end

    context 'when show_text is false' do
      subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options, show_text: false }
      
      before { render_inline(subject) }

      it 'does not render the text preview div' do
        # The px-4 mt-2 mb-2 div should not be present when show_text is false
        expect(rendered_content).not_to match(/<div class="px-4 mt-2 mb-2">/)
      end

      it 'uses rounded-xl on image' do
        expect(rendered_content).to include('rounded-xl')
      end

      it 'uses rounded-b-xl on title background' do
        expect(rendered_content).to include('rounded-b-xl')
      end

      it 'still renders the post title' do
        truncated_title = CGI.escapeHTML(post.title.truncate(100, separator: ' ', omission: ' ...'))
        expect(rendered_content).to include(truncated_title)
      end

      it 'still renders the post image' do
        expect(rendered_content).to include('object-cover')
      end
    end
  end
end

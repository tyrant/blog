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
  subject { PostComponent.new post: post, cms_site: site, nsfw_options: default_nsfw_options }

  describe '#initialize' do
    it { is_expected.to be_present }
  end

  describe 'rendering' do
    let(:expected_path) { "/blog/#{post.year}/#{post.month}/#{post.slug}" }
    let(:truncated_title) { post.title.truncate(72, separator: ' ', omission: ' ...') }
    
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
        it { expect(body_classes).to include('blur-sm') }
      end

      context 'when always visible' do
        let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => true, 'always' => true } }
        let(:body_classes) { subject.send(:css_classes_for_body) }
        it { expect(body_classes).not_to include('blur-sm') }
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
      it { expect(category_classes).to include('blur-sm') }
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
end

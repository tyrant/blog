require 'rails_helper'

RSpec.describe PrevNekComponent, type: :component do
  include ViewComponent::TestHelpers

  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:category1) { create :category, label: 'Whimsy', site: site }
  let!(:category2) { create :category, label: 'NSFW', site: site }
  
  let!(:post1) { create :post, site: site, layout: layout, published_at: 3.days.ago }
  let!(:post2) { create :post, site: site, layout: layout, published_at: 2.days.ago }
  let!(:post3) { create :post, site: site, layout: layout, published_at: 1.day.ago }
  
  let!(:categorization1) { create :categorization, category: category1, categorized: post1 }
  let!(:categorization2) { create :categorization, category: category2, categorized: post3 }

  let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => false, 'always' => false } }
  
  let(:category) { nil }
  subject { PrevNekComponent.new category: category, 
                                 post: post2, 
                                 site: site, 
                                 nsfw_options: default_nsfw_options }

  describe '#initialize' do
    describe 'accepting required parameters' do
      let(:category) { category1 }
      it { is_expected.to be_present }
    end

    describe 'accepting nil category' do
      it { is_expected.to be_present }
    end
  end

  describe 'rendering' do
    describe 'rendering the component' do
      before { render_inline(subject) }
      it { expect(rendered_component).to be_present }
    end
  end

  describe 'prev and nek methods' do
    describe 'finding previous post' do
      before { allow(post2).to receive(:prev).with(category: nil, nsfw: true).and_return post1 }
      it { expect(subject.send(:prev)).to eq post1 }
    end

    describe 'finding next post' do
      before { allow(post2).to receive(:nek).with(category: nil, nsfw: true).and_return post3 }
      it { expect(subject.send(:nek)).to eq post3 }
    end

    describe 'finding next post' do
      before { allow(post2).to receive(:nek).with(category: nil, nsfw: true).and_return post3 }
      it { expect(subject.send(:nek)).to eq post3 }
    end

    describe 'respecting NSFW banish setting' do
      before { default_nsfw_options.merge!('banish' => true) }
      it { expect(post2).to receive(:prev).with(category: nil, nsfw: false); subject.prev }
      it { expect(post2).to receive(:nek).with(category: nil, nsfw: false); subject.nek }
    end

    describe 'caching prev and nek results' do
      before do
        allow(post2).to receive(:prev).and_return(post1)
        allow(post2).to receive(:nek).and_return(post3)
        # Call twice to test caching
        subject.send(:prev)
        subject.send(:prev)
        subject.send(:nek)
        subject.send(:nek)
      end
      
      it { expect(post2).to have_received(:prev).once }
      it { expect(post2).to have_received(:nek).once }
    end
  end

  describe 'thumbnail methods' do
    describe 'prev_thumb_or_kiss' do
      context 'when prev post exists' do
        before do
          allow(subject).to receive(:prev).and_return(post1)
          allow(post1).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/image.jpg')
        end
        it { expect(subject.send(:prev_thumb_or_kiss)).to eq('/test/image.jpg') }
      end

      context 'when prev post does not exist' do
        before { allow(subject).to receive(:prev).and_return(nil) }
        it { expect(subject.send(:prev_thumb_or_kiss)).to eq('kissy-transparent.png') }
      end
    end

    describe 'nek_thumb_or_kiss' do
      context 'when nek post exists' do
        before do
          allow(subject).to receive(:nek).and_return(post3)
          allow(post3).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/nek.jpg')
        end
        it { expect(subject.send(:nek_thumb_or_kiss)).to eq('/test/nek.jpg') }
      end

      context 'when nek post does not exist' do
        before { allow(subject).to receive(:nek).and_return(nil) }
        it { expect(subject.send(:nek_thumb_or_kiss)).to eq('kissy-transparent.png') }
      end
    end
  end

  describe 'path methods' do
    describe 'prev_path' do
      context 'when prev post exists' do
        let(:expected_path) { "/blog/#{post1.year}/#{post1.month}/#{post1.slug}" }
        before do
          allow(subject).to receive(:prev).and_return(post1)
          render_inline(subject) # Establish view context
        end
        it { expect(subject.send(:prev_path)).to eq(expected_path) }
      end

      context 'when prev post does not exist' do
        before { allow(subject).to receive(:prev).and_return(nil) }
        it { expect(subject.send(:prev_path)).to eq('') }
      end
    end

    describe 'nek_path' do
      context 'when nek post exists' do
        let(:expected_path) { "/blog/#{post3.year}/#{post3.month}/#{post3.slug}" }
        before do
          allow(subject).to receive(:nek).and_return(post3)
          render_inline(subject) # Establish view context
        end
        it { expect(subject.send(:nek_path)).to eq(expected_path) }
      end

      context 'when nek post does not exist' do
        before { allow(subject).to receive(:nek).and_return(nil) }
        it { expect(subject.send(:nek_path)).to eq('') }
      end
    end
  end

  describe 'CSS classes' do
    describe 'prev_css_classes' do
      let(:css_classes) { subject.send(:prev_css_classes) }
      
      context 'with base classes' do
        before { allow(subject).to receive(:prev).and_return(post1) }
        it { expect(css_classes).to include('w-full', 'h-20', 'bg-center', 'transition') }
        it { expect(css_classes).to include('rounded-t-xl', 'xs:rounded-tr-none', 'xs:rounded-l-xl') }
        it { expect(css_classes).to include('duration-150') }
      end

      context 'when post is NSFW' do
        before do
          allow(subject).to receive(:prev).and_return(post3)
          allow(post3).to receive(:nsfw?).and_return(true)
        end
        it { expect(css_classes).to include('nsfw', 'blur-sm') }
      end

      context 'when mouseover is enabled' do
        let(:category) { nil }
        subject { PrevNekComponent.new category: category, post: post2, site: site, nsfw_options: default_nsfw_options.merge('mouseover' => true) }
        before do
          allow(subject).to receive(:prev).and_return(post3)
          allow(post3).to receive(:nsfw?).and_return(true)
        end
        it { expect(css_classes).to include('hover:blur-none') }
      end

      context 'when always is enabled' do
        let(:category) { nil }
        subject { PrevNekComponent.new category: category, post: post2, site: site, nsfw_options: default_nsfw_options.merge('always' => true) }
        before do
          allow(subject).to receive(:prev).and_return(post3)
          allow(post3).to receive(:nsfw?).and_return(true)
        end
        it { expect(css_classes).to include('nsfw') }
        it { expect(css_classes).not_to include('blur-sm') }
      end
    end

    describe 'nek_css_classes' do
      let(:css_classes) { subject.send(:nek_css_classes) }
      
      context 'with base classes' do
        before { allow(subject).to receive(:nek).and_return(post3) }
        it { expect(css_classes).to include('w-full', 'h-20', 'bg-center', 'transition') }
        it { expect(css_classes).to include('rounded-b-xl', 'xs:rounded-bl-none', 'xs:rounded-r-xl') }
        it { expect(css_classes).to include('duration-150') }
      end
    end
  end

  describe 'category CSS classes' do
    let(:css_classes) { subject.send(:css_classes_for_category) }
    
    context 'with specific category' do
      let(:category) { category1 }
      it { expect(css_classes).to include('h-6', 'w-[7rem]', 'text-center', 'shadow-lg') }
      it { expect(css_classes).to include('bg-indigo-100', 'text-indigo-800') }
    end

    context 'with nil category (all-posts)' do
      it { expect(css_classes).to include('bg-gray-100', 'text-gray-900') }
    end
  end
end

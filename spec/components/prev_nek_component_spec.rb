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

  describe '#initialize' do
    it 'accepts required parameters' do
      component = PrevNekComponent.new(
        category: category1, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      expect(component).to be_present
    end

    it 'accepts nil category' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      expect(component).to be_present
    end
  end

  describe 'rendering' do
    it 'renders the component' do
      render_inline(PrevNekComponent.new(
        category: category1, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      ))
      expect(rendered_component).to be_present
    end
  end

  describe 'prev and nek methods' do
    it 'finds previous post' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(post2).to receive(:prev).with(category: nil, nsfw: true).and_return(post1)
      expect(component.send(:prev)).to eq(post1)
    end

    it 'finds next post' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(post2).to receive(:nek).with(category: nil, nsfw: true).and_return(post3)
      expect(component.send(:nek)).to eq(post3)
    end

    it 'respects NSFW banish setting' do
      nsfw_options = default_nsfw_options.merge('banish' => true)
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: nsfw_options
      )
      
      expect(post2).to receive(:prev).with(category: nil, nsfw: false)
      expect(post2).to receive(:nek).with(category: nil, nsfw: false)
      
      component.send(:prev)
      component.send(:nek)
    end

    it 'caches prev and nek results' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(post2).to receive(:prev).and_return(post1)
      allow(post2).to receive(:nek).and_return(post3)
      
      # Call twice to test caching
      prev1 = component.send(:prev)
      prev2 = component.send(:prev)
      nek1 = component.send(:nek)
      nek2 = component.send(:nek)
      
      expect(prev1).to eq(prev2)
      expect(nek1).to eq(nek2)
      expect(post2).to have_received(:prev).once
      expect(post2).to have_received(:nek).once
    end
  end

  describe 'thumbnail methods' do
    it 'returns image URL when prev post exists' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(post1)
      allow(post1).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/image.jpg')
      
      expect(component.send(:prev_thumb_or_kiss)).to eq('/test/image.jpg')
    end

    it 'returns kissy image when prev post does not exist' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(nil)
      
      expect(component.send(:prev_thumb_or_kiss)).to eq('kissy-transparent.png')
    end

    it 'returns image URL when nek post exists' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:nek).and_return(post3)
      allow(post3).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('/test/nek.jpg')
      
      expect(component.send(:nek_thumb_or_kiss)).to eq('/test/nek.jpg')
    end

    it 'returns kissy image when nek post does not exist' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:nek).and_return(nil)
      
      expect(component.send(:nek_thumb_or_kiss)).to eq('kissy-transparent.png')
    end
  end

  describe 'path methods' do
    it 'returns correct path when prev post exists' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(post1)
      
      # Render the component to establish view context
      render_inline(component)
      
      expected_path = "/blog/#{post1.year}/#{post1.month}/#{post1.slug}"
      expect(component.send(:prev_path)).to eq(expected_path)
    end

    it 'returns empty string when prev post does not exist' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(nil)
      
      expect(component.send(:prev_path)).to eq('')
    end

    it 'returns correct path when nek post exists' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:nek).and_return(post3)
      
      # Render the component to establish view context
      render_inline(component)
      
      expected_path = "/blog/#{post3.year}/#{post3.month}/#{post3.slug}"
      expect(component.send(:nek_path)).to eq(expected_path)
    end

    it 'returns empty string when nek post does not exist' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:nek).and_return(nil)
      
      expect(component.send(:nek_path)).to eq('')
    end
  end

  describe 'CSS classes' do
    it 'includes base CSS classes for prev' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(post1)
      css_classes = component.send(:prev_css_classes)
      
      expect(css_classes).to include('w-full', 'h-20', 'bg-center', 'transition')
      expect(css_classes).to include('rounded-t-xl', 'xs:rounded-tr-none', 'xs:rounded-l-xl')
      expect(css_classes).to include('duration-150')
    end

    it 'includes base CSS classes for nek' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:nek).and_return(post3)
      css_classes = component.send(:nek_css_classes)
      
      expect(css_classes).to include('w-full', 'h-20', 'bg-center', 'transition')
      expect(css_classes).to include('rounded-b-xl', 'xs:rounded-bl-none', 'xs:rounded-r-xl')
      expect(css_classes).to include('duration-150')
    end

    it 'includes NSFW classes when post is NSFW' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(post3)
      allow(post3).to receive(:nsfw?).and_return(true)
      css_classes = component.send(:prev_css_classes)
      
      expect(css_classes).to include('nsfw', 'blur-sm')
    end

    it 'includes hover:blur-none when mouseover is enabled' do
      nsfw_options = default_nsfw_options.merge('mouseover' => true)
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(post3)
      allow(post3).to receive(:nsfw?).and_return(true)
      css_classes = component.send(:prev_css_classes)
      
      expect(css_classes).to include('hover:blur-none')
    end

    it 'does not include blur-sm when always is enabled' do
      nsfw_options = default_nsfw_options.merge('always' => true)
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: nsfw_options
      )
      
      allow(component).to receive(:prev).and_return(post3)
      allow(post3).to receive(:nsfw?).and_return(true)
      css_classes = component.send(:prev_css_classes)
      
      expect(css_classes).to include('nsfw')
      expect(css_classes).not_to include('blur-sm')
    end
  end

  describe 'category CSS classes' do
    it 'generates correct CSS for category' do
      component = PrevNekComponent.new(
        category: category1, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      css_classes = component.send(:css_classes_for_category)
      expect(css_classes).to include('h-6', 'w-[7rem]', 'text-center', 'shadow-lg')
      expect(css_classes).to include('bg-indigo-100', 'text-indigo-800')
    end

    it 'handles nil category as all-posts' do
      component = PrevNekComponent.new(
        category: nil, 
        post: post2, 
        site: site, 
        nsfw_options: default_nsfw_options
      )
      
      css_classes = component.send(:css_classes_for_category)
      expect(css_classes).to include('bg-gray-100', 'text-gray-900')
    end
  end
end

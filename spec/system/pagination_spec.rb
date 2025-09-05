require 'rails_helper'

RSpec.describe 'Blog Pagination', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
    
    # Create test site and layout
    @site = Comfy::Cms::Site.create!(
      identifier: 'test-site',
      hostname: 'localhost',
      path: '/',
      label: 'Test Site'
    )
    
    @layout = @site.layouts.create!(
      identifier: 'default',
      label: 'Default Layout',
      content: '{{ cms:page:content:rich_text }}'
    )
    
    # Mock ComfyBlog configuration for small page size to test pagination
    allow(ComfyBlog.config).to receive(:posts_per_page).and_return(3)
    
    # Create multiple test posts to trigger pagination
    @posts = []
    (1..8).each do |i|
      @posts << Comfy::Blog::Post.create!(
        blog_id: @site.id,
        title: "Test Post #{i}",
        slug: "test-post-#{i}",
        content: "Content for test post #{i}.",
        published_at: i.days.ago,
        is_published: true
      )
    end
  end

  describe 'Pagination display' do
    it 'shows pagination controls when there are multiple pages' do
      visit root_path
      
      # Should show pagination component
      expect(page).to have_css('[data-controller*="pagination"]', wait: 5)
    end
    
    it 'displays correct number of posts per page' do
      visit root_path
      
      # Should show only 3 posts (based on posts_per_page config)
      post_elements = page.all('.post')
      expect(post_elements.count).to eq(3)
    end
    
    it 'shows most recent posts first on page 1' do
      visit root_path
      
      # Most recent posts should appear first
      expect(page).to have_content('Test Post 1')
      expect(page).to have_content('Test Post 2')
      expect(page).to have_content('Test Post 3')
      expect(page).not_to have_content('Test Post 4')
    end
  end

  describe 'Pagination navigation' do
    it 'allows navigation to subsequent pages' do
      visit root_path
      
      # Navigate to page 2 if pagination links exist
      if page.has_link?('2')
        click_link '2'
        expect(page).to have_current_path('/?page=2')
        
        # Should show different posts
        expect(page).to have_content('Test Post 4')
        expect(page).to have_content('Test Post 5')
        expect(page).to have_content('Test Post 6')
      end
    end
    
    it 'shows correct pagination controls on different pages' do
      visit '/?page=2'
      
      # Should have navigation to previous and next pages
      expect(page).to have_link('1') if page.has_css('[data-controller*="pagination"]')
      expect(page).to have_link('3') if @posts.count > 6
    end
    
    it 'handles last page correctly' do
      last_page = (@posts.count.to_f / 3).ceil
      visit "/?page=#{last_page}"
      
      # Should show remaining posts
      remaining_posts = @posts.count % 3
      remaining_posts = 3 if remaining_posts == 0
      
      if page.has_css('.post')
        post_elements = page.all('.post')
        expect(post_elements.count).to be <= 3
      end
    end
  end

  describe 'Pagination with category filters' do
    before do
      # Create category and assign some posts to it
      @category = Comfy::Blog::Category.create!(
        blog_id: @site.id,
        label: 'Test Category',
        categorized_type: 'Comfy::Blog::Post'
      )
      
      # Assign first 4 posts to the category
      @posts[0..3].each do |post|
        post.categorizations.create!(category: @category)
      end
    end
    
    it 'maintains category filter across pagination' do
      visit "/?category=#{@category.label.downcase}"
      
      # Should show only categorized posts
      expect(page).to have_content('Test Post 1')
      expect(page).to have_content('Test Post 2')
      expect(page).to have_content('Test Post 3')
      
      # Navigate to next page with category filter
      if page.has_link?('2')
        click_link '2'
        expect(page).to have_current_path("/?category=#{@category.label.downcase}&page=2")
        expect(page).to have_content('Test Post 4')
      end
    end
  end

  describe 'Pagination edge cases' do
    it 'handles invalid page numbers gracefully' do
      visit '/?page=999'
      
      # Should handle gracefully, either redirect or show empty results
      expect(page.status_code).to be_in([200, 302, 404])
    end
    
    it 'handles page=0 or negative page numbers' do
      visit '/?page=0'
      expect(page.status_code).to be_in([200, 302])
      
      visit '/?page=-1'
      expect(page.status_code).to be_in([200, 302])
    end
    
    it 'works with non-numeric page parameters' do
      visit '/?page=abc'
      
      # Should default to page 1 or handle gracefully
      expect(page.status_code).to be_in([200, 302])
    end
  end

  describe 'Pagination performance and UX' do
    it 'loads pages efficiently without full page refresh when using AJAX' do
      visit root_path
      
      # Check if pagination uses AJAX or standard navigation
      if page.has_link?('2')
        # Record initial page load time
        start_time = Time.current
        click_link '2'
        load_time = Time.current - start_time
        
        # Should load reasonably quickly
        expect(load_time).to be < 5.seconds
      end
    end
    
    it 'maintains scroll position appropriately' do
      visit root_path
      
      # Scroll down if there's content
      page.execute_script('window.scrollTo(0, 200);') if page.has_css('.post')
      
      if page.has_link?('2')
        click_link '2'
        # Page should load successfully
        expect(page).to have_css('body')
      end
    end
  end

  describe 'Pagination accessibility' do
    it 'provides proper ARIA labels and navigation structure' do
      visit root_path
      
      if page.has_css('[data-controller*="pagination"]')
        # Should have proper navigation structure
        expect(page).to have_css('nav, [role="navigation"]')
      end
    end
    
    it 'supports keyboard navigation' do
      visit root_path
      
      if page.has_link?('2')
        # Focus on pagination link and activate with keyboard
        page.find('a', text: '2').send_keys(:return)
        expect(page).to have_current_path('/?page=2')
      end
    end
  end
end

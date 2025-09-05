require 'rails_helper'

RSpec.describe 'Blog Browsing', type: :system do
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
    
    # Create test categories
    @general_category = Comfy::Blog::Category.create!(
      blog_id: @site.id,
      label: 'General',
      categorized_type: 'Comfy::Blog::Post'
    )
    
    @nsfw_category = Comfy::Blog::Category.create!(
      blog_id: @site.id,
      label: 'NSFW',
      categorized_type: 'Comfy::Blog::Post'
    )
    
    # Create test posts
    @published_post = Comfy::Blog::Post.create!(
      blog_id: @site.id,
      title: 'Test Published Post',
      slug: 'test-published-post',
      content: 'This is a test published post content.',
      published_at: 1.day.ago,
      is_published: true
    )
    
    @nsfw_post = Comfy::Blog::Post.create!(
      blog_id: @site.id,
      title: 'NSFW Test Post',
      slug: 'nsfw-test-post',
      content: 'This is NSFW content.',
      published_at: 2.days.ago,
      is_published: true
    )
    
    # Add categorizations
    @published_post.categorizations.create!(category: @general_category)
    @nsfw_post.categorizations.create!(category: @nsfw_category)
    
    # Mock ComfyBlog configuration
    allow(ComfyBlog.config).to receive(:posts_per_page).and_return(10)
  end

  describe 'Homepage blog listing' do
    it 'displays published blog posts' do
      visit root_path
      
      expect(page).to have_content('Test Published Post')
      expect(page).to have_content('NSFW Test Post')
    end
    
    it 'shows post previews with proper styling' do
      visit root_path
      
      # Check for post component structure
      expect(page).to have_css('[data-post-nsfw-value]')
      expect(page).to have_css('.post')
    end
    
    it 'allows clicking on post titles to view full posts' do
      visit root_path
      
      click_link 'Test Published Post'
      expect(page).to have_current_path("/#{@published_post.slug}")
      expect(page).to have_content('This is a test published post content.')
    end
  end

  describe 'Individual post pages' do
    it 'displays full post content' do
      visit "/#{@published_post.slug}"
      
      expect(page).to have_content('Test Published Post')
      expect(page).to have_content('This is a test published post content.')
    end
    
    it 'shows navigation to previous/next posts' do
      visit "/#{@published_post.slug}"
      
      # Should have prev/nek navigation components
      expect(page).to have_css('[data-controller*="prev-nek"]')
    end
    
    it 'handles NSFW posts appropriately' do
      visit "/#{@nsfw_post.slug}"
      
      expect(page).to have_content('NSFW Test Post')
      # Should have NSFW-related data attributes
      expect(page).to have_css('[data-post-nsfw-value="true"]')
    end
  end

  describe 'Category filtering' do
    it 'filters posts by category' do
      visit "/?category=#{@general_category.label.downcase}"
      
      expect(page).to have_content('Test Published Post')
      expect(page).not_to have_content('NSFW Test Post')
    end
    
    it 'shows NSFW posts when filtering by NSFW category' do
      visit "/?category=#{@nsfw_category.label.downcase}"
      
      expect(page).to have_content('NSFW Test Post')
      expect(page).not_to have_content('Test Published Post')
    end
    
    it 'shows all posts when no category filter is applied' do
      visit root_path
      
      expect(page).to have_content('Test Published Post')
      expect(page).to have_content('NSFW Test Post')
    end
  end

  describe 'NSFW content handling integration' do
    before do
      # Set up NSFW cookies for testing
      page.driver.browser.manage.add_cookie(name: 'nsfw_banish', value: 'false')
      page.driver.browser.manage.add_cookie(name: 'nsfw_mouseover', value: 'true')
      page.driver.browser.manage.add_cookie(name: 'nsfw_always', value: 'false')
    end
    
    it 'respects NSFW settings across page navigation' do
      visit root_path
      
      # NSFW post should be visible but potentially blurred
      expect(page).to have_content('NSFW Test Post')
      
      # Navigate to individual post
      click_link 'NSFW Test Post'
      expect(page).to have_current_path("/#{@nsfw_post.slug}")
      
      # NSFW content should still respect settings
      expect(page).to have_css('[data-post-nsfw-value="true"]')
    end
    
    it 'maintains NSFW preferences when browsing between posts' do
      visit "/#{@nsfw_post.slug}"
      
      # Should have consent component
      expect(page).to have_css('[data-controller*="consent-is-sexy-yo"]')
      
      # Navigate to another post and back
      visit "/#{@published_post.slug}"
      visit "/#{@nsfw_post.slug}"
      
      # NSFW settings should persist
      expect(page).to have_css('[data-controller*="consent-is-sexy-yo"]')
    end
  end

  describe 'Navigation and user experience' do
    it 'provides working navigation between posts' do
      # Create additional posts for navigation testing
      older_post = Comfy::Blog::Post.create!(
        blog_id: @site.id,
        title: 'Older Post',
        slug: 'older-post',
        content: 'Older content.',
        published_at: 3.days.ago,
        is_published: true
      )
      
      newer_post = Comfy::Blog::Post.create!(
        blog_id: @site.id,
        title: 'Newer Post',
        slug: 'newer-post',
        content: 'Newer content.',
        published_at: Time.current,
        is_published: true
      )
      
      visit "/#{@published_post.slug}"
      
      # Should have navigation elements
      expect(page).to have_css('[data-controller*="prev-nek"]')
      
      # Verify the posts exist for navigation
      expect(older_post).to be_persisted
      expect(newer_post).to be_persisted
    end
    
    it 'shows responsive navigation menu' do
      visit root_path
      
      # Should have navigation component
      expect(page).to have_css('nav[data-controller*="nav"]')
      expect(page).to have_css('[data-action*="toggleMobile"]')
    end
    
    it 'provides dark mode toggle functionality' do
      visit root_path
      
      # Should have dark mode toggle
      expect(page).to have_css('[data-action*="dark-mode#toggle"]')
    end
  end

  describe 'Landing page integration' do
    it 'shows landing page banner and allows navigation' do
      visit root_path
      
      # Should have landing banner
      expect(page).to have_css('[data-nav-target="landingDiv"]')
      expect(page).to have_content('Flirts GALORE')
    end
    
    it 'allows interaction with landing page elements' do
      visit root_path
      
      # Click on landing banner link
      within('[data-nav-target="landingDiv"]') do
        expect(page).to have_link(href: '/landing')
      end
    end
  end

  describe 'Error handling and edge cases' do
    it 'handles non-existent post URLs gracefully' do
      visit '/non-existent-post'
      
      # Should show 404 or redirect appropriately
      expect(page.status_code).to be_in([404, 302])
    end
    
    it 'handles empty blog state' do
      # Remove all posts
      Comfy::Blog::Post.destroy_all
      
      visit root_path
      
      # Should still render page without errors
      expect(page).to have_css('nav')
    end
  end
end

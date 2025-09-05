require 'rails_helper'

RSpec.describe 'NSFW Content Integration', type: :system do
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
    @nsfw_category = Comfy::Blog::Category.create!(
      blog_id: @site.id,
      label: 'NSFW',
      categorized_type: 'Comfy::Blog::Post'
    )
    
    @general_category = Comfy::Blog::Category.create!(
      blog_id: @site.id,
      label: 'General',
      categorized_type: 'Comfy::Blog::Post'
    )
    
    # Create test posts
    @nsfw_post = Comfy::Blog::Post.create!(
      blog_id: @site.id,
      title: 'NSFW Test Post',
      slug: 'nsfw-test-post',
      content: 'This is NSFW content that should be filtered.',
      published_at: 1.day.ago,
      is_published: true
    )
    
    @general_post = Comfy::Blog::Post.create!(
      blog_id: @site.id,
      title: 'General Test Post',
      slug: 'general-test-post',
      content: 'This is general content.',
      published_at: 2.days.ago,
      is_published: true
    )
    
    # Add categorizations
    @nsfw_post.categorizations.create!(category: @nsfw_category)
    @general_post.categorizations.create!(category: @general_category)
  end

  describe 'NSFW consent component functionality' do
    it 'displays consent component on pages with NSFW content' do
      visit root_path
      
      # Should have consent component
      expect(page).to have_css('[data-controller*="consent-is-sexy-yo"]')
    end
    
    it 'allows toggling NSFW banish setting' do
      visit root_path
      
      # Find and interact with banish checkbox
      banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      
      # Toggle banish setting using JavaScript click to avoid interception
      page.execute_script("arguments[0].click();", banish_checkbox)
      
      # Verify the setting was applied
      expect(page).to have_css('[data-consent-is-sexy-yo-banish-value="true"]')
    end
    
    it 'allows toggling mouseover setting when banish is false' do
      visit root_path
      
      # Ensure banish is false first
      banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      if page.has_css('[data-consent-is-sexy-yo-banish-value="true"]')
        page.execute_script("arguments[0].click();", banish_checkbox)
      end
      
      # Toggle mouseover setting
      mouseover_checkbox = page.find('[data-consent-is-sexy-yo-target="mouseoverCheckbox"]')
      page.execute_script("arguments[0].click();", mouseover_checkbox)
      
      # Verify the setting was applied
      expect(page).to have_css('[data-consent-is-sexy-yo-mouseover-value="true"]')
    end
    
    it 'allows toggling always setting when conditions are met' do
      visit root_path
      
      # Set up conditions: banish false, mouseover true
      banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      mouseover_checkbox = page.find('[data-consent-is-sexy-yo-target="mouseoverCheckbox"]')
      
      # Ensure banish is false
      if page.has_css('[data-consent-is-sexy-yo-banish-value="true"]')
        page.execute_script("arguments[0].click();", banish_checkbox)
      end
      
      # Ensure mouseover is true
      if page.has_css('[data-consent-is-sexy-yo-mouseover-value="false"]')
        page.execute_script("arguments[0].click();", mouseover_checkbox)
      end
      
      # Now toggle always setting
      always_checkbox = page.find('[data-consent-is-sexy-yo-target="alwaysCheckbox"]')
      page.execute_script("arguments[0].click();", always_checkbox)
      
      # Verify the setting was applied
      expect(page).to have_css('[data-consent-is-sexy-yo-always-value="true"]')
    end
  end

  describe 'NSFW content visibility across pages' do
    it 'hides NSFW posts when banish is enabled' do
      visit root_path
      
      # Enable banish setting
      banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      page.execute_script("arguments[0].click();", banish_checkbox)
      
      # NSFW posts should be hidden
      nsfw_posts = page.all('[data-post-nsfw-value="true"]')
      nsfw_posts.each do |post|
        expect(post[:class]).to include('hidden')
      end
    end
    
    it 'shows NSFW posts with blur effects when banish is disabled' do
      visit root_path
      
      # Ensure banish is disabled
      if page.has_css('[data-consent-is-sexy-yo-banish-value="true"]')
        banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
        page.execute_script("arguments[0].click();", banish_checkbox)
      end
      
      # NSFW posts should be visible but potentially blurred
      nsfw_posts = page.all('[data-post-nsfw-value="true"]')
      expect(nsfw_posts).not_to be_empty
      
      nsfw_posts.each do |post|
        expect(post[:class]).not_to include('hidden')
      end
    end
    
    it 'removes blur effects when always is enabled' do
      visit root_path
      
      # Set up conditions for always: banish false, mouseover true, always true
      banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      mouseover_checkbox = page.find('[data-consent-is-sexy-yo-target="mouseoverCheckbox"]')
      always_checkbox = page.find('[data-consent-is-sexy-yo-target="alwaysCheckbox"]')
      
      # Ensure proper state
      if page.has_css('[data-consent-is-sexy-yo-banish-value="true"]')
        page.execute_script("arguments[0].click();", banish_checkbox)
      end
      
      if page.has_css('[data-consent-is-sexy-yo-mouseover-value="false"]')
        page.execute_script("arguments[0].click();", mouseover_checkbox)
      end
      
      if page.has_css('[data-consent-is-sexy-yo-always-value="false"]')
        page.execute_script("arguments[0].click();", always_checkbox)
      end
      
      # Check that blur effects are removed
      nsfw_posts = page.all('[data-post-nsfw-value="true"]')
      nsfw_posts.each do |post|
        expect(post[:class]).not_to include('blur-sm')
      end
    end
  end

  describe 'NSFW settings persistence' do
    it 'maintains NSFW settings across page navigation' do
      visit root_path
      
      # Set specific NSFW preferences
      banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      page.execute_script("arguments[0].click();", banish_checkbox)
      
      # Navigate to individual post
      visit "/#{@general_post.slug}"
      
      # Navigate back to homepage
      visit root_path
      
      # Settings should persist
      expect(page).to have_css('[data-consent-is-sexy-yo-banish-value="true"]')
    end
    
    it 'applies NSFW settings to individual post pages' do
      visit root_path
      
      # Set NSFW preferences
      if page.has_css('[data-consent-is-sexy-yo-banish-value="true"]')
        banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
        page.execute_script("arguments[0].click();", banish_checkbox)
      end
      
      # Navigate to NSFW post
      visit "/#{@nsfw_post.slug}"
      
      # NSFW content should respect settings
      expect(page).to have_css('[data-post-nsfw-value="true"]')
    end
  end

  describe 'NSFW category filtering integration' do
    it 'respects NSFW settings when filtering by NSFW category' do
      visit "/?category=nsfw"
      
      # Should show NSFW category posts
      expect(page).to have_content('NSFW Test Post')
      
      # Should still have consent component
      expect(page).to have_css('[data-controller*="consent-is-sexy-yo"]')
    end
    
    it 'hides NSFW category posts when banish is enabled' do
      visit "/?category=nsfw"
      
      # Enable banish
      banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      page.execute_script("arguments[0].click();", banish_checkbox)
      
      # NSFW posts should be hidden even in NSFW category
      nsfw_posts = page.all('[data-post-nsfw-value="true"]')
      nsfw_posts.each do |post|
        expect(post[:class]).to include('hidden')
      end
    end
  end

  describe 'NSFW hover effects' do
    it 'applies hover effects when mouseover is enabled' do
      visit root_path
      
      # Ensure mouseover is enabled and always is disabled
      if page.has_css('[data-consent-is-sexy-yo-banish-value="true"]')
        banish_checkbox = page.find('[data-consent-is-sexy-yo-target="banishCheckbox"]')
        page.execute_script("arguments[0].click();", banish_checkbox)
      end
      
      if page.has_css('[data-consent-is-sexy-yo-mouseover-value="false"]')
        mouseover_checkbox = page.find('[data-consent-is-sexy-yo-target="mouseoverCheckbox"]')
        page.execute_script("arguments[0].click();", mouseover_checkbox)
      end
      
      if page.has_css('[data-consent-is-sexy-yo-always-value="true"]')
        always_checkbox = page.find('[data-consent-is-sexy-yo-target="alwaysCheckbox"]')
        page.execute_script("arguments[0].click();", always_checkbox)
      end
      
      # NSFW posts should have hover:blur-none class
      nsfw_posts = page.all('[data-post-nsfw-value="true"]')
      nsfw_posts.each do |post|
        expect(post[:class]).to include('hover:blur-none')
      end
    end
  end

  describe 'NSFW accessibility and UX' do
    it 'provides clear visual feedback for NSFW settings' do
      visit root_path
      
      # Consent component should be visible and accessible
      consent_component = page.find('[data-controller*="consent-is-sexy-yo"]')
      expect(consent_component).to be_present
      
      # Should have clear labels and indicators
      expect(page).to have_css('[data-consent-is-sexy-yo-target="banishCheckbox"]')
      expect(page).to have_css('[data-consent-is-sexy-yo-target="mouseoverCheckbox"]')
      expect(page).to have_css('[data-consent-is-sexy-yo-target="alwaysCheckbox"]')
    end
    
    it 'maintains consistent NSFW styling across different page types' do
      # Test on homepage
      visit root_path
      homepage_nsfw_styling = page.all('[data-post-nsfw-value="true"]').first[:class] if page.has_css('[data-post-nsfw-value="true"]')
      
      # Test on individual post page
      visit "/#{@nsfw_post.slug}"
      post_page_nsfw_styling = page.find('[data-post-nsfw-value="true"]')[:class] if page.has_css('[data-post-nsfw-value="true"]')
      
      # NSFW styling should be consistent
      if homepage_nsfw_styling && post_page_nsfw_styling
        expect(homepage_nsfw_styling).to include('blur-sm') if post_page_nsfw_styling.include?('blur-sm')
      end
    end
  end

  describe 'NSFW error handling' do
    it 'handles missing NSFW cookies gracefully' do
      # Clear all cookies
      page.driver.browser.manage.delete_all_cookies
      
      visit root_path
      
      # Should still render without errors
      expect(page).to have_css('[data-controller*="consent-is-sexy-yo"]')
    end
    
    it 'works when JavaScript is disabled' do
      # Disable JavaScript
      page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', enabled: true)
      
      visit root_path
      
      # Basic NSFW content should still be handled appropriately
      expect(page).to have_css('[data-post-nsfw-value]')
      
      # Re-enable JavaScript
      page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', enabled: false)
    end
  end
end

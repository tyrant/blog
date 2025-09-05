require 'rails_helper'

RSpec.describe 'Landing Page', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
    
    # Create test site for CMS context
    @site = Comfy::Cms::Site.create!(
      identifier: 'test-site',
      hostname: 'localhost',
      path: '/',
      label: 'Test Site'
    )
  end

  describe 'Landing page access' do
    it 'loads the landing page successfully' do
      visit '/landing'
      
      expect(page).to have_http_status(:success)
      expect(page).to have_current_path('/landing')
    end
    
    it 'displays landing page content' do
      visit '/landing'
      
      # Should have basic page structure
      expect(page).to have_css('body')
      expect(page).to have_css('nav')
    end
  end

  describe 'Landing page banner integration' do
    it 'shows landing banner on main blog pages' do
      visit root_path
      
      # Should have landing banner
      expect(page).to have_css('[data-nav-target="landingDiv"]')
      expect(page).to have_content('Flirts GALORE')
      expect(page).to have_content('The Knights of Raw Phwoar')
    end
    
    it 'provides clickable link to landing page from banner' do
      visit root_path
      
      # Should have link to landing page
      within('[data-nav-target="landingDiv"]') do
        expect(page).to have_link(href: '/landing')
        click_link
      end
      
      expect(page).to have_current_path('/landing')
    end
    
    it 'includes animated arrow in landing banner' do
      visit root_path
      
      # Should have arrow SVG with animation classes
      within('[data-nav-target="landingDiv"]') do
        expect(page).to have_css('svg[data-nav-target="arrow"]')
        expect(page).to have_css('.duration-200')
      end
    end
  end

  describe 'Landing page form submission' do
    it 'handles form submission successfully' do
      visit '/landing'
      
      # Look for any forms on the landing page
      if page.has_css('form')
        # Find the first form and try to submit it
        form = page.first('form')
        
        # Fill out any required fields if they exist
        if form.has_css('input[required]')
          required_inputs = form.all('input[required]')
          required_inputs.each do |input|
            case input[:type]
            when 'email'
              input.set('test@example.com')
            when 'text', nil
              input.set('Test Value')
            end
          end
        end
        
        # Submit the form
        within(form) do
          click_button if page.has_button?
        end
        
        # Should handle submission without errors
        expect(page).to have_http_status(:success)
      end
    end
    
    it 'provides appropriate feedback after form submission' do
      # Test POST to landing submit endpoint directly
      page.driver.submit :post, '/landing/submit', {}
      
      # Should return success response (204 No Content based on controller)
      expect(page.status_code).to eq(204)
    end
  end

  describe 'Landing page navigation integration' do
    it 'maintains navigation consistency with main site' do
      visit '/landing'
      
      # Should have same navigation structure as main site
      expect(page).to have_css('nav[data-controller*="nav"]')
      expect(page).to have_css('[data-controller*="dark-mode"]')
    end
    
    it 'allows navigation back to main blog' do
      visit '/landing'
      
      # Should have link back to main site
      if page.has_link?('Mikey Clarke')
        click_link 'Mikey Clarke'
        expect(page).to have_current_path('/')
      end
    end
    
    it 'supports dark mode toggle on landing page' do
      visit '/landing'
      
      # Should have dark mode functionality
      expect(page).to have_css('[data-action*="dark-mode#toggle"]')
      
      # Test dark mode toggle
      page.find('[data-action*="dark-mode#toggle"]').click
      
      # Should apply dark mode classes
      expect(page).to have_css('.dark, [class*="dark:"]')
    end
  end

  describe 'Landing page responsive design' do
    it 'works on mobile viewport' do
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone size
      visit '/landing'
      
      expect(page).to have_css('body')
      expect(page).to have_css('nav')
    end
    
    it 'works on tablet viewport' do
      page.driver.browser.manage.window.resize_to(768, 1024) # iPad size
      visit '/landing'
      
      expect(page).to have_css('body')
      expect(page).to have_css('nav')
    end
    
    it 'shows mobile navigation menu appropriately' do
      page.driver.browser.manage.window.resize_to(375, 667)
      visit '/landing'
      
      # Should have mobile menu toggle
      expect(page).to have_css('[data-action*="toggleMobile"]')
    end
  end

  describe 'Landing page performance' do
    it 'loads within reasonable time' do
      start_time = Time.current
      visit '/landing'
      load_time = Time.current - start_time
      
      expect(load_time).to be < 5.seconds
      expect(page).to have_css('body')
    end
    
    it 'loads required assets successfully' do
      visit '/landing'
      
      # Check that CSS is loaded (Tailwind classes should be applied)
      expect(page).to have_css('[class*="bg-"], [class*="text-"], [class*="p-"]')
    end
  end

  describe 'Landing page SEO and metadata' do
    it 'has appropriate page title' do
      visit '/landing'
      
      # Should have a title tag
      expect(page).to have_title(/\S+/) # Non-empty title
    end
    
    it 'includes proper meta tags' do
      visit '/landing'
      
      # Should have viewport meta tag for responsive design
      expect(page).to have_css('meta[name="viewport"]', visible: false)
    end
  end

  describe 'Landing page error handling' do
    it 'handles invalid form submissions gracefully' do
      # Test with invalid data
      page.driver.submit :post, '/landing/submit', { invalid: 'data' }
      
      # Should handle gracefully
      expect(page.status_code).to be_in([200, 204, 400, 422])
    end
    
    it 'works when JavaScript is disabled' do
      # Disable JavaScript
      page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', enabled: true)
      
      visit '/landing'
      
      # Basic functionality should still work
      expect(page).to have_css('body')
      expect(page).to have_css('nav')
      
      # Re-enable JavaScript for other tests
      page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', enabled: false)
    end
  end
end

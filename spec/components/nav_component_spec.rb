require 'rails_helper'

RSpec.describe NavComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:nav_items) { [] }
  let(:component) { described_class.new(nav_items: nav_items) }

  # Mock nav item structure
  let(:nav_item_without_children) do
    double('NavItem', 
           label: 'Home', 
           path: '/', 
           key: 'home',
           children: [])
  end

  let(:nav_child) do
    double('NavChild',
           label: 'Child Item',
           path: '/child',
           children: [])
  end

  let(:nav_grandchild) do
    double('NavGrandchild',
           label: 'Grandchild Item',
           path: '/grandchild',
           children: [])
  end

  let(:nav_child_with_grandchildren) do
    double('NavChildWithGrandchildren',
           label: 'Parent Child',
           path: '/parent-child',
           children: [nav_grandchild])
  end

  let(:nav_item_with_children) do
    double('NavItemWithChildren',
           label: 'Blog',
           path: '/blog',
           key: 'blog',
           children: [nav_child, nav_child_with_grandchildren])
  end

  describe '#initialize' do
    it 'sets the nav_items attribute' do
      expect(component.instance_variable_get(:@nav_items)).to eq(nav_items)
    end
  end

  describe 'rendering' do
    before do
      # Mock Rails route helpers
      allow(component).to receive(:landing_index_path).and_return('/landing')
      allow(component).to receive(:root_path).and_return('/')
      allow(component).to receive(:image_tag).with('kissy-transparent.png', class: 'h-9 w-auto dark:invert').and_return('<img src="kissy-transparent.png" class="h-9 w-auto dark:invert" />'.html_safe)
    end

    subject { render_inline(component) }

    it 'renders the component successfully' do
      expect(subject).to be_present
    end

    it 'includes the nav and dark-mode controller data attributes' do
      nav_element = subject.css('nav[data-controller*="nav"][data-controller*="dark-mode"]').first
      expect(nav_element).to be_present
    end

    it 'applies correct CSS classes for fixed navigation' do
      nav_element = subject.css('nav').first
      expect(nav_element['class']).to include('fixed top-0 w-full z-50')
      expect(nav_element['class']).to include('bg-white dark:bg-gray-800')
      expect(nav_element['class']).to include('shadow-lg')
    end

    it 'renders the landing banner section' do
      landing_div = subject.css('[data-nav-target="landingDiv"]').first
      expect(landing_div).to be_present
      expect(landing_div['class']).to include('bg-cyan-900 dark:bg-cyan-950')
    end

    it 'includes the landing link with correct text' do
      expect(subject.text).to include('Flirts GALORE: read The Knights of Raw Phwoar FREE omg')
    end

    it 'renders the site logo and title' do
      expect(subject.text).to include('Mikey Clarke')
      logo_link = subject.css('a[href="/"]').first
      expect(logo_link).to be_present
    end

    it 'includes the mobile menu toggle button' do
      toggle_button = subject.css('button[data-action="click->nav#toggleMobile"]').first
      expect(toggle_button).to be_present
      expect(toggle_button['class']).to include('md:hidden')
    end

    it 'includes dark mode toggle buttons for both mobile and desktop' do
      dark_mode_buttons = subject.css('button[data-action="dark-mode#toggle"]')
      expect(dark_mode_buttons.length).to eq(2) # One for mobile, one for desktop
    end

    it 'includes screen reader text for accessibility' do
      expect(subject.text).to include('Open main menu')
      expect(subject.text).to include('Toggle dark mode')
    end

    context 'with empty nav items' do
      let(:nav_items) { [] }

      it 'renders without navigation items' do
        # Mobile nav should be empty
        mobile_nav = subject.css('[data-nav-target="mobile"] ul').first
        nav_links = mobile_nav.css('li a') if mobile_nav
        expect(nav_links&.length || 0).to eq(0)

        # Desktop nav should be empty
        desktop_nav = subject.css('.nav ul').last
        nav_links = desktop_nav.css('li a') if desktop_nav
        expect(nav_links&.length || 0).to eq(0)
      end
    end

    context 'with simple nav items' do
      let(:nav_items) { [nav_item_without_children] }

      it 'renders navigation items in mobile menu' do
        mobile_links = subject.css('[data-nav-target="mobile"] a')
        home_link = mobile_links.find { |link| link.text.include?('Home') }
        expect(home_link).to be_present
        expect(home_link['href']).to eq('/')
      end

      it 'renders navigation items in desktop menu' do
        desktop_links = subject.css('.nav ul a')
        home_link = desktop_links.find { |link| link.text.include?('Home') }
        expect(home_link).to be_present
        expect(home_link['href']).to eq('/')
      end

      it 'applies correct font styling to nav links' do
        nav_links = subject.css("a[class*=\"font-['Racing_Sans_One']\"]")
        expect(nav_links.length).to be > 0
      end
    end

    context 'with nested nav items' do
      let(:nav_items) { [nav_item_with_children] }

      it 'renders parent navigation items' do
        expect(subject.text).to include('Blog')
      end

      it 'renders child navigation items in mobile menu' do
        expect(subject.text).to include('Child Item')
        expect(subject.text).to include('Parent Child')
      end

      it 'renders grandchild navigation items in mobile menu' do
        expect(subject.text).to include('Grandchild Item')
      end

      it 'includes submenu data attributes for desktop navigation' do
        submenu_trigger = subject.css('[data-nav-target="blogMenu"]').first
        expect(submenu_trigger).to be_present
        expect(submenu_trigger['data-action']).to include('mouseover->nav#openBlogSubmenu')
        expect(submenu_trigger['data-action']).to include('mouseout->nav#closeBlogSubmenu')
      end

      it 'renders desktop submenu structure' do
        submenu = subject.css('[data-nav-target="blogSubmenu"]').first
        expect(submenu).to be_present
        expect(submenu['class']).to include('hidden')
        expect(submenu['class']).to include('absolute')
      end

      it 'applies correct nesting classes for mobile menu' do
        # Child items should have ml-4 class
        mobile_nav = subject.css('[data-nav-target="mobile"]').first
        child_lists = mobile_nav.css('ul ul')
        expect(child_lists.length).to be > 0
        
        # Grandchild items should be italic
        grandchild_items = mobile_nav.css('li.italic')
        expect(grandchild_items.length).to be > 0
      end

      it 'applies correct styling for desktop submenu items' do
        desktop_submenu = subject.css('[data-nav-target="blogSubmenu"]').first
        submenu_items = desktop_submenu.css('li')
        expect(submenu_items.length).to be > 0
        
        # Check for grandchild italic styling
        italic_items = desktop_submenu.css('.italic')
        expect(italic_items.length).to be > 0
      end
    end

    context 'responsive design' do
      it 'hides mobile menu by default' do
        mobile_menu = subject.css('[data-nav-target="mobile"]').first
        expect(mobile_menu['class']).to include('hidden md:hidden')
      end

      it 'hides desktop menu on mobile' do
        desktop_menu = subject.css('.hidden.md\\:flex').first
        expect(desktop_menu).to be_present
      end

      it 'shows mobile toggle button only on mobile' do
        toggle_button = subject.css('button[data-action="click->nav#toggleMobile"]').first
        expect(toggle_button['class']).to include('md:hidden')
      end
    end

    context 'dark mode support' do
      it 'includes dark mode classes throughout the component' do
        # Navigation background
        nav_element = subject.css('nav').first
        expect(nav_element['class']).to include('dark:bg-gray-800')
        
        # Text colors
        expect(subject.to_html).to include('dark:text-gray-300')
        
        # Hover states
        expect(subject.to_html).to include('dark:hover:bg-gray-700')
      end

      it 'includes dark mode toggle functionality' do
        dark_mode_buttons = subject.css('button[data-action="dark-mode#toggle"]')
        expect(dark_mode_buttons.length).to eq(2)
      end
    end
  end
end

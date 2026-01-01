# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NavComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:nav_items) { [] }
  subject { described_class.new nav_items: nav_items }

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
    it { expect(subject.instance_variable_get(:@nav_items)).to eq(nav_items) }
  end

  describe 'rendering' do
    before do
      # Mock Rails route helpers
      allow(subject).to receive(:landing_index_path).and_return('/landing')
      allow(subject).to receive(:root_path).and_return('/')
      allow(subject).to receive(:image_tag).with('kissy-transparent.png', class: 'h-9 w-auto dark:invert').and_return('<img src="kissy-transparent.png" class="h-9 w-auto dark:invert" />'.html_safe)
    end

    let(:rendered) { render_inline(subject) }
    let(:nav_element) { rendered.css('nav').first }
    let(:landing_div) { rendered.css('[data-nav-target="landingDiv"]').first }
    let(:logo_link) { rendered.css('a[href="/"]').first }
    let(:toggle_button) { rendered.css('button[data-action="click->nav#toggleMobile"]').first }
    let(:dark_mode_buttons) { rendered.css('button[data-action="dark-mode#toggle"]') }

    it { expect(rendered).to be_present }
    it { expect(rendered.css('nav[data-controller*="nav"][data-controller*="dark-mode"]').first).to be_present }
    it { expect(nav_element['class']).to include('fixed top-0 w-full z-50') }
    it { expect(nav_element['class']).to include('bg-white dark:bg-gray-800') }
    it { expect(nav_element['class']).to include('shadow-lg') }
    it { expect(landing_div).to be_present }
    it { expect(landing_div['class']).to include('bg-cyan-900 dark:bg-cyan-950') }
    it { expect(rendered.text).to include('Flirts GALORE: read The Knights of Raw Phwoar FREE omg') }
    it { expect(rendered.text).to include('Mikey Clarke') }
    it { expect(logo_link).to be_present }
    it { expect(toggle_button).to be_present }
    it { expect(toggle_button['class']).to include('md:hidden') }
    it { expect(dark_mode_buttons.length).to eq(2) }
    it { expect(rendered.text).to include('Open main menu') }
    it { expect(rendered.text).to include('Toggle dark mode') }

    context 'with empty nav items' do
      let(:nav_items) { [] }
      let(:mobile_nav) { rendered.css('[data-nav-target="mobile"] ul').first }
      let(:desktop_nav) { rendered.css('.nav ul').last }
      let(:mobile_nav_links) { mobile_nav&.css('li a') }
      let(:desktop_nav_links) { desktop_nav&.css('li a') }
      it { expect(mobile_nav_links&.length || 0).to eq(0) }
      it { expect(desktop_nav_links&.length || 0).to eq(0) }
    end

    context 'with simple nav items' do
      let(:nav_items) { [nav_item_without_children] }
      let(:mobile_links) { rendered.css('[data-nav-target="mobile"] a') }
      let(:desktop_links) { rendered.css('.nav ul a') }
      let(:mobile_home_link) { mobile_links.find { |link| link.text.include?('Home') } }
      let(:desktop_home_link) { desktop_links.find { |link| link.text.include?('Home') } }
      let(:nav_links) { rendered.css("a[class*=\"font-['Racing_Sans_One']\"]") }
      
      it { expect(mobile_home_link).to be_present }
      it { expect(mobile_home_link['href']).to eq('/') }
      it { expect(desktop_home_link).to be_present }
      it { expect(desktop_home_link['href']).to eq('/') }
      it { expect(nav_links.length).to be > 0 }
    end

    context 'with nested nav items' do
      let(:nav_items) { [nav_item_with_children] }
      let(:submenu_trigger) { rendered.css('[data-nav-target="blogMenu"]').first }
      let(:submenu) { rendered.css('[data-nav-target="blogSubmenu"]').first }
      let(:mobile_nav) { rendered.css('[data-nav-target="mobile"]').first }
      let(:child_lists) { mobile_nav.css('ul ul') }
      let(:grandchild_items) { mobile_nav.css('li.italic') }
      let(:desktop_submenu) { rendered.css('[data-nav-target="blogSubmenu"]').first }
      let(:submenu_items) { desktop_submenu.css('li') }
      let(:italic_items) { desktop_submenu.css('.italic') }

      it { expect(rendered.text).to include('Blog') }
      it { expect(rendered.text).to include('Child Item') }
      it { expect(rendered.text).to include('Parent Child') }
      it { expect(rendered.text).to include('Grandchild Item') }
      it { expect(submenu_trigger).to be_present }
      it { expect(submenu_trigger['data-action']).to include('mouseover->nav#openBlogSubmenu') }
      it { expect(submenu_trigger['data-action']).to include('mouseout->nav#closeBlogSubmenu') }
      it { expect(submenu).to be_present }
      it { expect(submenu['class']).to include('hidden') }
      it { expect(submenu['class']).to include('absolute') }
      it { expect(child_lists.length).to be > 0 }
      it { expect(grandchild_items.length).to be > 0 }
      it { expect(submenu_items.length).to be > 0 }
      it { expect(italic_items.length).to be > 0 }
    end

    context 'responsive design' do
      let(:mobile_menu) { rendered.css('[data-nav-target="mobile"]').first }
      let(:desktop_menu) { rendered.css('.hidden.md\:flex').first }
      let(:mobile_toggle_button) { rendered.css('button[data-action="click->nav#toggleMobile"]').first }
      
      it { expect(mobile_menu['class']).to include('hidden md:hidden') }
      it { expect(desktop_menu).to be_present }
      it { expect(mobile_toggle_button['class']).to include('md:hidden') }
    end

    context 'dark mode support' do
      it { expect(nav_element['class']).to include('dark:bg-gray-800') }
      it { expect(rendered.to_html).to include('dark:text-gray-300') }
      it { expect(rendered.to_html).to include('dark:hover:bg-gray-700') }
      it { expect(dark_mode_buttons.length).to eq(2) }
    end
  end
end

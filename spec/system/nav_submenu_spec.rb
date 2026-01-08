# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Nav submenu show/hide', type: :system do
  let!(:site) { create :site, identifier: 'nav-test-site', hostname: 'nav.localhost', path: '/', label: 'Nav Test Site' }
  let!(:category) { create :category, site: site, label: 'Whimsy', categorized_type: 'Comfy::Blog::Post' }

  before do
    page.driver.browser.manage.window.resize_to(1280, 800)
    visit root_path
  end

  describe 'Books submenu' do
    let(:books_menu) { find('[data-nav-target="booksMenu"]') }
    let(:books_submenu) { find('[data-nav-target="booksSubmenu"]', visible: :all) }

    context 'on mouseover' do
      before { books_menu.hover }

      it { expect(books_submenu).to be_visible }
      it { expect(books_submenu[:class]).to include('block') }
      it { expect(books_submenu[:class]).not_to include('hidden') }
    end

    context 'on mouseout' do
      before do
        books_menu.hover
        find('body').hover
      end

      it { expect(books_submenu).not_to be_visible }
    end
  end

  describe 'Blog submenu' do
    let(:blog_menu) { find('[data-nav-target="blogMenu"]') }
    let(:blog_submenu) { find('[data-nav-target="blogSubmenu"]', visible: :all) }

    context 'on mouseover' do
      before { blog_menu.hover }

      it { expect(blog_submenu).to be_visible }
      it { expect(blog_submenu[:class]).to include('block') }
      it { expect(blog_submenu[:class]).not_to include('hidden') }
    end

    context 'on mouseout' do
      before do
        blog_menu.hover
        find('body').hover
      end

      it { expect(blog_submenu).not_to be_visible }
    end
  end
end

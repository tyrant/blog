# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Blog post autosave', type: :system do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:blog_post) { create :post, site: site, layout: layout }

  let(:username) { ComfortableMexicanSofa::AccessControl::AdminAuthentication.username }
  let(:password) { ComfortableMexicanSofa::AccessControl::AdminAuthentication.password }

  before do
    page.driver.browser.manage.window.resize_to(1280, 800)
  end

  describe 'autosave indicator' do
    context 'on edit page' do
      before do
        visit "http://#{username}:#{password}@#{Capybara.server_host}:#{Capybara.server_port}/admin/sites/#{site.id}/blog-posts/#{blog_post.id}/edit"
      end

      it { expect(page).to have_selector('form[action*="/blog-posts/"]') }

      it 'has CMS.autosave defined' do
        result = page.evaluate_script('typeof window.CMS !== "undefined" && typeof window.CMS.autosave !== "undefined"')
        expect(result).to be true
      end

      it 'creates autosave indicator after manual init' do
        # Re-run init to ensure it runs after page is fully loaded
        page.execute_script('window.CMS.autosave.init()')
        expect(page).to have_css('.autosave-indicator', wait: 2)
      end
    end

    context 'on new post page' do
      before do
        visit "http://#{username}:#{password}@#{Capybara.server_host}:#{Capybara.server_port}/admin/sites/#{site.id}/blog-posts/new"
      end

      it { expect(page).not_to have_css('.autosave-indicator') }
    end
  end
end

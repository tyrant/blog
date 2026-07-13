# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tags Select2', type: :system do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:blog_post) { create :post, site: site, layout: layout }
  let!(:tag) { Tag.create!(name: 'writing') }

  let(:username) { ComfortableMexicanSofa::AccessControl::AdminAuthentication.username }
  let(:password) { ComfortableMexicanSofa::AccessControl::AdminAuthentication.password }

  before do
    page.driver.browser.manage.window.resize_to(1280, 800)
    visit "http://#{username}:#{password}@#{Capybara.server_host}:#{Capybara.server_port}/admin/sites/#{site.id}/blog-posts/#{blog_post.id}/edit"
  end

  it 'enhances the tags multi-select with Select2' do
    expect(page).to have_css('.tags-widget .select2-container', wait: 4)
  end

  it 'offers the existing tags as Select2 options' do
    find('.tags-widget .select2-selection').click
    expect(page).to have_css('.select2-results__option', text: 'writing', wait: 4)
  end
end

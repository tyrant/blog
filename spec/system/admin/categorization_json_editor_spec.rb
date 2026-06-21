# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Categorization JSON editor', type: :system do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:blog_post) { create :post, site: site, layout: layout }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) do
    create :categorization, category: category, categorized: blog_post,
           data: { 'notes' => %w[a b], 'blizzard' => [] }
  end

  let(:username) { ComfortableMexicanSofa::AccessControl::AdminAuthentication.username }
  let(:password) { ComfortableMexicanSofa::AccessControl::AdminAuthentication.password }

  before do
    page.driver.browser.manage.window.resize_to(1280, 800)
    visit "http://#{username}:#{password}@#{Capybara.server_host}:#{Capybara.server_port}/admin/sites/#{site.id}/blog-posts/#{blog_post.id}/edit"
  end

  it 'renders the #data field as a CodeMirror editor' do
    expect(page).to have_css('.CodeMirror', wait: 4)
  end

  it 'shows the JSON fold gutter (the +/- controls)' do
    expect(page).to have_css('.CodeMirror-foldgutter', wait: 4)
  end
end

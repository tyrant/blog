# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Quotation Substack user Select2', type: :system do
  let!(:site) { create :site }
  let!(:bob) { create :substack_user, name: 'Bob', handle: 'bob' }
  let!(:eva) { create :substack_user, name: 'Eva', handle: 'eva' }
  let!(:quotation) { SubstackQuotation.create!(quotation: 'zing', comment_url: 'https://x/comment/1', substack_user: bob) }

  before do
    # The list's Blizzard thank-you wording draws two distinct compliments; configured as in prod.
    SubstackSyncConfig.instance.update!(subtitle_variables_json: { compliment: %w[spiffy cracking] }.to_json)
    page.driver.browser.manage.window.resize_to(1280, 800)
    sign_in_admin_in_browser
    visit "http://#{Capybara.server_host}:#{Capybara.server_port}/admin/quotations/#{quotation.id}/edit"
  end

  it 'enhances the Substack user select with Select2' do
    expect(page).to have_css('.select2-container .select2-selection__rendered', text: 'Bob (@bob)', wait: 4)
  end

  context 'when searching the picker' do
    before do
      find('.select2-selection--single').click
      find('.select2-search__field').send_keys('ev')
    end

    it 'offers matching users' do
      expect(page).to have_css('.select2-results__option', text: 'Eva (@eva)', wait: 4)
    end

    it 'filters out non-matching users' do
      expect(page).to have_no_css('.select2-results__option', text: 'Bob (@bob)', wait: 4)
    end
  end

  context 'when picking another user and saving' do
    before do
      find('.select2-selection--single').click
      find('.select2-search__field').send_keys('eva')
      find('.select2-results__option', text: 'Eva (@eva)').click
      click_button 'Update quotation'
    end

    it 'links the picked user' do
      expect(page).to have_content('Quotation updated.', wait: 4) and expect(quotation.reload.substack_user).to eq eva
    end
  end
end

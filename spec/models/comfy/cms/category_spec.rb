# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Category, type: :model do
  let!(:site) { create :site }
  let!(:category) { create :category, site: site }

  before { reset_cms_config }

  describe 'associations' do
    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_many(:categorizations).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:categorized_type) }
  end

  describe '#boolean?' do
    it { expect(create(:category, site: site, label: 'NSFW')).to be_boolean }
    it { expect(category).to be_boolean }
    it { expect(create(:category, site: site, label: 'Shite Advice')).to be_boolean }
    it { expect(create(:category, site: site, label: 'Medium')).to_not be_boolean }
  end

  describe 'scopes' do
    let!(:page_category) { create :category, site: site, categorized_type: 'Comfy::Cms::Page' }
    let!(:file_category) { create :category, site: site, categorized_type: 'Comfy::Cms::File' }

    describe '.of_type' do
      it { expect(Comfy::Cms::Category.of_type('Comfy::Cms::Page')).to include page_category }
      it { expect(Comfy::Cms::Category.of_type('Comfy::Cms::Page')).to_not include file_category }
    end
  end
end

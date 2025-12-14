# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Category, type: :model do
  let!(:site) { create(:site) }
  let!(:category) { create(:category, site: site) }

  before { reset_cms_config }

  describe 'associations' do
    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_many(:categorizations).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:categorized_type) }
  end

  describe 'scopes' do
    let!(:page_category) { create(:category, site: site, categorized_type: 'Comfy::Cms::Page') }
    let!(:file_category) { create(:category, site: site, categorized_type: 'Comfy::Cms::File') }

    describe '.of_type' do
      it 'filters by categorized_type' do
        expect(Comfy::Cms::Category.of_type('Comfy::Cms::Page')).to include(page_category)
        expect(Comfy::Cms::Category.of_type('Comfy::Cms::Page')).not_to include(file_category)
      end
    end
  end
end

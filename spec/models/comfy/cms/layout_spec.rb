# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Layout, type: :model do
  let!(:site) { create(:site) }
  let!(:layout) { create(:layout, site: site) }

  before { reset_cms_config }

  describe 'associations' do
    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_many(:pages).dependent(:nullify) }
    it { is_expected.to have_many(:children).class_name('Comfy::Cms::Layout').dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:site_id) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:identifier) }
  end

  describe 'automatic label assignment' do
    let(:layout_without_label) { build(:layout, site: site, identifier: 'test-layout', label: nil) }

    it 'assigns titleized label from identifier' do
      layout_without_label.valid?
      expect(layout_without_label.label).to eq('Test Layout')
    end
  end

  describe 'nested layouts' do
    let!(:child_layout) { create(:layout, site: site, parent: layout, identifier: 'child-layout') }

    it 'has parent-child relationship' do
      expect(child_layout.parent).to eq(layout)
      expect(layout.children.reload).to include(child_layout)
    end
  end

  describe '#content_with_app_layout' do
    context 'when app_layout is set' do
      before { layout.update(app_layout: 'application') }

      it 'wraps content with app layout yield' do
        expect(layout.app_layout).to eq('application')
      end
    end
  end
end

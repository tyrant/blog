# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Snippet, type: :model do
  let!(:site) { create :site }
  let!(:snippet) { create :snippet, site: site }

  before { reset_cms_config }

  describe 'associations' do
    it { is_expected.to belong_to(:site) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_uniqueness_of(:identifier).scoped_to(:site_id) }
  end

  describe 'automatic label assignment' do
    let(:snippet_without_label) { build :snippet, site: site, identifier: 'test-snippet', label: nil }

    before { snippet_without_label.valid? }

    it { expect(snippet_without_label.label).to eq 'Test Snippet' }
  end

  describe 'content' do
    before { snippet.update(content: '<p>Test content</p>') }

    it { expect(snippet.content).to eq '<p>Test content</p>' }
  end
end

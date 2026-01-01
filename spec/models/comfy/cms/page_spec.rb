# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Page, type: :model do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:page) { create :page, site: site, layout: layout }

  before { reset_cms_config }

  describe 'associations' do
    it { is_expected.to belong_to(:site) }
    it { is_expected.to belong_to(:layout) }
    it { is_expected.to have_many(:children).class_name('Comfy::Cms::Page').dependent(:destroy) }
    it { is_expected.to have_many(:translations).class_name('Comfy::Cms::Translation').dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:layout) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:slug) }
  end

  describe 'full_path generation' do
    context 'for root page' do
      let(:root_page) { create :page, site: site, layout: layout, slug: 'index', parent: nil }

      it { expect(root_page.full_path).to eq '/index' }
    end

    context 'for nested page' do
      let!(:parent_page) { create :page, site: site, layout: layout, slug: 'parent' }
      let!(:child_page) { create :page, site: site, layout: layout, slug: 'child', parent: parent_page }

      it { expect(child_page.full_path).to eq '/parent/child' }
    end
  end

  describe 'scopes' do
    describe '.published' do
      let!(:published_page) { create :page, site: site, layout: layout, is_published: true }
      let!(:unpublished_page) { create :page, site: site, layout: layout, is_published: false }

      it { expect(Comfy::Cms::Page.published).to include published_page }
      it { expect(Comfy::Cms::Page.published).to_not include unpublished_page }
    end
  end

  describe '#url' do
    it { expect(page.url).to include "//#{site.hostname}" }
    it { expect(page.url(relative: true)).to start_with '/' }
  end
end

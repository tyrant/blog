# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Fragment, type: :model do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:page) { create :page, site: site, layout: layout }
  let!(:fragment) { create :fragment, record: page }

  before { reset_cms_config }

  describe 'associations' do
    it { is_expected.to belong_to(:record) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:identifier) }
  end

  describe 'content storage' do
    context 'with text content' do
      before { fragment.update(content: 'Test content') }

      it { expect(fragment.content).to eq 'Test content' }
    end

    context 'with datetime content' do
      let(:time) { Time.current }

      before { fragment.update(datetime: time) }

      it { expect(fragment.datetime).to be_within(1.second).of(time) }
    end

    context 'with boolean content' do
      before { fragment.update(boolean: true) }

      it { expect(fragment.boolean).to be true }
    end
  end

  describe 'tag association' do
    before { fragment.update(tag: 'wysiwyg') }

    it { expect(fragment.tag).to eq 'wysiwyg' }
  end
end

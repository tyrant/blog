# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Fragment, type: :model do
  let!(:site) { create(:site) }
  let!(:layout) { create(:layout, site: site) }
  let!(:page) { create(:page, site: site, layout: layout) }
  let!(:fragment) { create(:fragment, record: page) }

  before { reset_cms_config }

  describe 'associations' do
    it { is_expected.to belong_to(:record) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:identifier) }
  end

  describe 'content storage' do
    it 'stores text content' do
      fragment.update(content: 'Test content')
      expect(fragment.content).to eq('Test content')
    end

    it 'stores datetime content' do
      time = Time.current
      fragment.update(datetime: time)
      expect(fragment.datetime).to be_within(1.second).of(time)
    end

    it 'stores boolean content' do
      fragment.update(boolean: true)
      expect(fragment.boolean).to be true
    end
  end

  describe 'tag association' do
    it 'stores tag type' do
      fragment.update(tag: 'wysiwyg')
      expect(fragment.tag).to eq('wysiwyg')
    end
  end
end

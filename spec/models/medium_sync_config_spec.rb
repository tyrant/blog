# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediumSyncConfig, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:title_template) }
    it { is_expected.to validate_presence_of(:content_template) }
    it { is_expected.to validate_presence_of(:link_template) }
  end

  describe '.instance' do
    context 'when no record exists' do
      it 'creates a record' do
        expect { described_class.instance }.to change { described_class.count }.by 1
      end

      it 'returns a MediumSyncConfig' do
        expect(described_class.instance).to be_an_instance_of described_class
      end

      it 'uses the default title_template' do
        expect(described_class.instance.title_template).to eq '{{title}}'
      end

      it 'uses the default content_template' do
        expect(described_class.instance.content_template).to eq '{{content}}'
      end

      it 'uses the default link_template' do
        expect(described_class.instance.link_template).to eq 'original: {{url}}'
      end

      it 'leaves subtitle blank' do
        expect(described_class.instance.subtitle).to be_blank
      end

      it 'leaves footer_html blank' do
        expect(described_class.instance.footer_html).to be_blank
      end
    end

    context 'when a record already exists' do
      before { described_class.instance }

      it 'returns the existing record without creating another' do
        expect { described_class.instance }.not_to change { described_class.count }
      end

      it 'does not reset customised field values' do
        described_class.first.update!(title_template: 'Custom Title')
        expect(described_class.instance.title_template).to eq 'Custom Title'
      end
    end
  end
end

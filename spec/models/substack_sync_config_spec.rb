# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackSyncConfig do
  describe 'validations' do
    subject(:config) { described_class.instance }

    it 'is valid with a nil footer' do
      config.footer_json = nil
      expect(config).to be_valid
    end

    it 'is valid with an array footer' do
      config.footer_json = [{ 'type' => 'button' }]
      expect(config).to be_valid
    end

    it 'is invalid when the footer is not an array' do
      config.footer_json = { 'type' => 'button' }
      expect(config).to_not be_valid
    end
  end

  describe '#footer_json_text' do
    subject(:config) { described_class.instance }

    it 'renders the footer as pretty JSON' do
      config.footer_json = [{ 'type' => 'button' }]
      expect(config.footer_json_text).to eq JSON.pretty_generate([{ 'type' => 'button' }])
    end

    it 'defaults to an empty array when unset' do
      config.footer_json = nil
      expect(config.footer_json_text).to eq "[]"
    end
  end

  describe '#footer_json_text=' do
    subject(:config) { described_class.instance }

    it 'parses valid JSON into footer_json' do
      config.footer_json_text = '[{"type":"button"}]'
      expect(config.footer_json).to eq [{ 'type' => 'button' }]
    end

    it 'marks the record invalid on unparseable JSON' do
      config.footer_json_text = 'not json'
      expect(config).to_not be_valid
    end
  end

  describe '.instance' do
    it { expect(described_class.instance).to be_persisted }

    it 'returns the same singleton row' do
      expect(described_class.instance.id).to eq described_class.instance.id
    end

    it 'creates the singleton even though footer_json is blank' do
      expect { described_class.instance }.to_not raise_error
    end
  end
end

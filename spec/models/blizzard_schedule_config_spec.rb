# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlizzardScheduleConfig do

  describe '.instance' do
    it { expect(described_class.instance).to be_persisted }

    it 'is a singleton (repeated calls return the same record)' do
      described_class.instance
      expect { described_class.instance }.to_not change { described_class.count }
    end
  end

  describe 'defaults' do
    it { expect(described_class.instance.cooldown_hours).to eq 12 }
    it { expect(described_class.instance.last_reposted_at).to be_nil }
    it { expect(described_class.instance.quotation_odds_pct).to eq 24 }
    it { expect(described_class.instance.unattached_odds_pct).to eq 2 }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:cooldown_hours).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:quotation_odds_pct).only_integer.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { is_expected.to validate_numericality_of(:unattached_odds_pct).only_integer.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }

    it 'rejects quotation + unattached odds over 100' do
      config = described_class.instance
      config.assign_attributes(quotation_odds_pct: 60, unattached_odds_pct: 50)
      expect(config).to_not be_valid
    end

    it 'allows quotation + unattached odds summing to exactly 100' do
      config = described_class.instance
      config.assign_attributes(quotation_odds_pct: 60, unattached_odds_pct: 40)
      expect(config).to be_valid
    end
  end

  describe '#text_group_odds_pct' do
    subject(:config) { described_class.instance }

    it 'is the remainder after quotation and unattached odds' do
      config.assign_attributes(quotation_odds_pct: 24, unattached_odds_pct: 2)
      expect(config.text_group_odds_pct).to eq 74
    end
  end

  describe '#data_json_text' do
    subject(:config) { described_class.instance }

    it 'renders the unattached-notes data as pretty JSON' do
      config.data = { 'notes' => ['https://x/note/c-1'] }
      expect(config.data_json_text).to eq JSON.pretty_generate('notes' => ['https://x/note/c-1'])
    end

    it 'defaults to {"notes"=>[]} when unset' do
      config.data = {}
      expect(config.data_json_text).to eq JSON.pretty_generate('notes' => [])
    end
  end

  describe '#data_json_text=' do
    subject(:config) { described_class.instance }

    it 'parses valid JSON into data' do
      config.data_json_text = '{"notes":["https://x/note/c-1"]}'
      expect(config.data).to eq('notes' => ['https://x/note/c-1'])
    end

    it 'marks the record invalid on unparseable JSON' do
      config.data_json_text = 'not json'
      expect(config).to_not be_valid
    end

    it 'marks the record invalid when the parsed JSON is not an object' do
      config.data_json_text = '["not", "a", "hash"]'
      expect(config).to_not be_valid
    end
  end
end

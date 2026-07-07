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
    it { expect(described_class.instance.interval_minutes).to eq 30 }
    it { expect(described_class.instance.cooldown_hours).to eq 12 }
    it { expect(described_class.instance.last_reposted_at).to be_nil }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:interval_minutes).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:cooldown_hours).only_integer.is_greater_than_or_equal_to(0) }
  end
end

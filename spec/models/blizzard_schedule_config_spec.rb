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

  describe '#schedule' do
    it 'defaults to an empty hash' do
      expect(described_class.instance.schedule).to eq({})
    end
  end
end

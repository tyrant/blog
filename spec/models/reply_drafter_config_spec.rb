# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReplyDrafterConfig do
  describe '.instance' do
    it { expect(described_class.instance).to be_persisted }

    it 'seeds the instructions with the default brief' do
      expect(described_class.instance.instructions).to eq Substack::ReplyGenerator::DEFAULT_INSTRUCTIONS
    end

    it 'defaults the knobs' do
      config = described_class.instance
      expect([config.count, config.split, config.length, config.model]).to eq [6, 'balanced', '1-3', 'claude-sonnet-5']
    end
  end

  describe 'validations' do
    subject(:config) { described_class.instance }

    it 'rejects a count above the cap' do
      config.count = 50
      expect(config).to_not be_valid
    end

    it 'rejects an unknown split' do
      config.split = 'whatever'
      expect(config).to_not be_valid
    end

    it 'rejects an unknown length' do
      config.length = '9'
      expect(config).to_not be_valid
    end
  end
end

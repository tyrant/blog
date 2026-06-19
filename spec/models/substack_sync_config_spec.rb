# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackSyncConfig do
  describe '.instance' do
    it { expect(described_class.instance).to be_persisted }

    it 'returns the same singleton row' do
      expect(described_class.instance.id).to eq described_class.instance.id
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecordBlizzardStatsJob do
  it 'records a stat snapshot' do
    expect(BlizzardStatSnapshot).to receive(:record!)
    described_class.perform_now
  end
end

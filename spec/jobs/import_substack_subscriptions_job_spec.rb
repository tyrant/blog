# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportSubstackSubscriptionsJob do

  before do
    allow(Substack::SubscriptionImporter).to receive(:execute)
    allow(CheckSubstackSubscriptionsJob).to receive(:perform_later)
    described_class.perform_now
  end

  it { expect(Substack::SubscriptionImporter).to have_received(:execute) }
  it { expect(CheckSubstackSubscriptionsJob).to have_received(:perform_later) }
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckSubstackSubscriptionsJob do

  let!(:unchecked) { create :substack_subscription }
  let!(:checked) { create :substack_subscription, :checked }

  before do
    allow_any_instance_of(described_class).to receive(:sleep)
    allow(Substack::SubscriptionChecker).to receive(:execute)
  end

  context 'by default' do
    before { described_class.perform_now }

    it { expect(Substack::SubscriptionChecker).to have_received(:execute).once }
    it { expect(Substack::SubscriptionChecker).to have_received(:execute).with(unchecked, client: an_instance_of(Substack::Client)) }
    it { expect(JobProgress.find_by(key: 'check_substack_subscriptions').status).to eq 'finished' }
  end

  context 'rechecking' do
    before { described_class.perform_now(recheck: true) }

    it { expect(Substack::SubscriptionChecker).to have_received(:execute).twice }
  end
end

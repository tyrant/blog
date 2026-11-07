# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Unsubscriber do
  subject(:unsubscribe) { described_class.execute(subscription, client: client) }

  let(:client) { instance_double(Substack::Client, unsubscribe: {}) }
  let!(:subscription) { create :substack_subscription, publication_subdomain: 'evawrites' }

  context 'when Substack confirms the subscription is gone' do
    before { allow(client).to receive(:publication_subscription).with('evawrites').and_return('is_subscribed' => false, 'is_free_subscribed' => false) }

    it 'unsubscribes on the publication’s subdomain and drops the row' do
      unsubscribe
      expect(client).to have_received(:unsubscribe).with('evawrites', subscription.publication_id)
      expect(SubstackSubscription.exists?(subscription.id)).to be false
    end
  end

  context 'when the follow-up lookup 404s' do
    before { allow(client).to receive(:publication_subscription).and_raise(Substack::Client::NotFound, '404') }

    it { expect { unsubscribe }.to change(SubstackSubscription, :count).by(-1) }
  end

  context 'when Substack still lists the subscription' do
    before { allow(client).to receive(:publication_subscription).and_return('is_subscribed' => true, 'is_free_subscribed' => true) }

    it 'raises and keeps the row' do
      expect { unsubscribe }.to raise_error(described_class::Error, /still lists/)
      expect(SubstackSubscription.exists?(subscription.id)).to be true
    end
  end

  context 'with a paid subscription' do
    let!(:subscription) { create :substack_subscription, membership_state: 'subscribed' }

    it 'refuses without calling Substack' do
      expect { unsubscribe }.to raise_error(described_class::Error, /Paid/)
      expect(client).not_to have_received(:unsubscribe)
    end
  end
end

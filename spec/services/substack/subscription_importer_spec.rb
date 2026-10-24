# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::SubscriptionImporter do

  let(:client) { instance_double(Substack::Client) }
  let(:first_page) do
    {
      'subscriptions' => [
        { 'id' => 1, 'publication_id' => 10, 'membership_state' => 'free_signup', 'created_at' => '2026-01-02T00:00:00Z' },
        { 'id' => 2, 'publication_id' => 20, 'membership_state' => 'free_signup', 'created_at' => '2026-01-03T00:00:00Z' }
      ],
      'publications' => [
        { 'id' => 10, 'name' => 'Eva Writes', 'subdomain' => 'eva', 'custom_domain' => nil, 'author_id' => 100 },
        { 'id' => 20, 'name' => 'My Own', 'subdomain' => 'me', 'custom_domain' => nil, 'author_id' => 4619740 }
      ],
      'nextCursor' => 99
    }
  end
  let(:second_page) do
    {
      'subscriptions' => [{ 'id' => 3, 'publication_id' => 30, 'membership_state' => 'subscribed', 'created_at' => '2026-01-04T00:00:00Z' }],
      'publications' => [{ 'id' => 30, 'name' => 'Paid One', 'subdomain' => 'paid', 'custom_domain' => 'paid.example', 'author_id' => 300 }],
      'nextCursor' => nil
    }
  end

  subject(:import) { described_class.execute(client: client, owner_id: 4619740) }

  before do
    allow_any_instance_of(described_class).to receive(:sleep)
    allow(client).to receive(:subscriptions_page).with(nil).and_return(first_page)
    allow(client).to receive(:subscriptions_page).with(99).and_return(second_page)
  end

  context 'importing' do
    before { import }

    it { expect(SubstackSubscription.pluck(:subscription_id)).to contain_exactly 1, 3 }
    it { expect(SubstackSubscription.find_by(subscription_id: 1).publication_name).to eq 'Eva Writes' }
    it { expect(SubstackSubscription.find_by(subscription_id: 1).author_id).to eq 100 }
    it { expect(SubstackSubscription.find_by(subscription_id: 3).publication_custom_domain).to eq 'paid.example' }
    it { expect(SubstackSubscription.find_by(subscription_id: 3).membership_state).to eq 'subscribed' }
  end

  it { expect(import).to eq 2 }

  context 'with a subscription since dropped' do
    let!(:dropped) { create :substack_subscription, subscription_id: 77 }

    before { import }

    it { expect(SubstackSubscription.exists?(dropped.id)).to be false }
  end

  context 'when Substack returns no subscriptions' do
    let!(:existing) { create :substack_subscription, subscription_id: 77 }

    before do
      allow(client).to receive(:subscriptions_page).with(nil).and_return({ 'subscriptions' => [], 'publications' => [], 'nextCursor' => nil })
      import
    end

    it { expect(SubstackSubscription.exists?(existing.id)).to be true }
  end

  context 'when a publication changes author' do
    let!(:existing) { create :substack_subscription, :checked, subscription_id: 1, author_id: 55, follows_me: true, author_handle: 'old' }

    before { import }

    it { expect(existing.reload.checked_at).to be_nil }
    it { expect(existing.reload.author_handle).to be_nil }
  end

  context 'when the author is unchanged' do
    let!(:existing) { create :substack_subscription, :checked, subscription_id: 1, author_id: 100, follows_me: true }

    before { import }

    it { expect(existing.reload.follows_me).to be true }
  end
end

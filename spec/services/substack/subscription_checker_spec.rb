# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::SubscriptionChecker do

  let(:client) { instance_double(Substack::Client) }
  let(:subscription) { create :substack_subscription, author_id: 42, publication_subdomain: 'evawrites' }
  let(:profile) do
    {
      'handle' => 'eva', 'name' => 'Eva Solen', 'followsViewer' => true, 'followerCount' => 966,
      'subscriptions' => [{ 'publication' => { 'id' => 514910, 'author_id' => 4619740 } }]
    }
  end

  subject(:check) { described_class.execute(subscription, client: client, owner_id: 4619740) }

  context 'when the subdomain is the handle' do
    before do
      allow(client).to receive(:public_profile).with(42, 'evawrites').and_return(profile)
      check
    end

    it { expect(subscription.reload.follows_me).to be true }
    it { expect(subscription.reload.subscribes_to_me).to be true }
    it { expect(subscription.reload.author_handle).to eq 'eva' }
    it { expect(subscription.reload.author_name).to eq 'Eva Solen' }
    it { expect(subscription.reload.author_follower_count).to eq 966 }
    it { expect(subscription.reload.checked_at).to be_present }
  end

  context 'when they neither follow nor publicly subscribe' do
    before do
      allow(client).to receive(:public_profile).and_return(profile.merge('followsViewer' => false, 'subscriptions' => []))
      check
    end

    it { expect(subscription.reload.follows_me).to be false }
    it { expect(subscription.reload.subscribes_to_me).to be false }
  end

  context 'without an owner id' do
    subject(:check) { described_class.execute(subscription, client: client, owner_id: nil) }

    before do
      allow(client).to receive(:public_profile).and_return(profile.merge('subscriptions' => [{ 'publication' => { 'id' => 1 } }]))
      check
    end

    it { expect(subscription.reload.subscribes_to_me).to be false }
  end

  context 'when the subdomain is not the handle' do
    before do
      allow(client).to receive(:public_profile).with(42, 'evawrites').and_raise(Substack::Client::NotFound, '404')
      allow(client).to receive(:handle_for).with(42).and_return('eva')
      allow(client).to receive(:public_profile).with(42, 'eva').and_return(profile)
      check
    end

    it { expect(subscription.reload.author_handle).to eq 'eva' }
  end

  context 'when no profile can be found' do
    before do
      allow(client).to receive(:public_profile).and_raise(Substack::Client::NotFound, '404')
      allow(client).to receive(:handle_for).and_return(nil)
      check
    end

    it { expect(subscription.reload.check_error).to eq 'No Substack profile found for user 42' }
    it { expect(subscription.reload.checked_at).to be_present }
  end

  context 'when the session is dead' do
    before { allow(client).to receive(:public_profile).and_raise(Substack::Client::AuthError, 'refresh it') }

    it { expect { check }.to raise_error Substack::Client::AuthError }
  end
end

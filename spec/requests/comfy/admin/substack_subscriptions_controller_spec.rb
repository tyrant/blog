# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SubstackSubscriptionsController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET index' do
    let!(:candidate) { create :substack_subscription, :checked, publication_name: 'Quiet Eva', author_handle: 'eva' }
    let!(:follower) { create :substack_subscription, :checked, publication_name: 'Friendly Bob', follows_me: true }

    context 'by default' do
      before { get comfy_admin_substack_subscriptions_path, headers: admin_headers }

      it { expect(response).to have_http_status :success }
      it { expect(response.body).to include 'Quiet Eva' }
      it { expect(response.body).to include 'https://substack.com/@eva' }
      it { expect(response.body).to_not include 'Friendly Bob' }
      it { expect(response.body).to include '2 of 5,000 subscriptions' }
    end

    context 'showing all' do
      before { get comfy_admin_substack_subscriptions_path(show: 'all'), headers: admin_headers }

      it { expect(response.body).to include 'Friendly Bob' }
    end

    context 'searching' do
      before { get comfy_admin_substack_subscriptions_path(show: 'all', q: 'bob'), headers: admin_headers }

      it { expect(response.body).to_not include 'Quiet Eva' }
    end

    context 'while a check is running' do
      before do
        JobProgress.begin!('check_substack_subscriptions', label: 'Check', total: 10)
        get comfy_admin_substack_subscriptions_path, headers: admin_headers
      end

      it { expect(response.body).to include 'Checking: 0 of 10' }
    end

    context 'with nothing imported' do
      before do
        SubstackSubscription.delete_all
        get comfy_admin_substack_subscriptions_path, headers: admin_headers
      end

      it { expect(response.body).to include 'No subscriptions imported yet' }
    end

    context 'more than one page' do
      before do
        50.times { create :substack_subscription, :checked, publication_name: 'Filler' }
        get comfy_admin_substack_subscriptions_path, headers: admin_headers
      end

      it { expect(response).to have_http_status :success }
    end
  end

  describe 'POST import' do
    it 'enqueues an import' do
      expect { post comfy_import_admin_substack_subscriptions_path, headers: admin_headers }
        .to have_enqueued_job ImportSubstackSubscriptionsJob
    end

    context 'while a check is running' do
      before { JobProgress.begin!('check_substack_subscriptions', label: 'Check', total: 10) }

      it 'refuses' do
        expect { post comfy_import_admin_substack_subscriptions_path, headers: admin_headers }
          .to_not have_enqueued_job ImportSubstackSubscriptionsJob
      end
    end
  end

  describe 'POST recheck' do
    it 'enqueues a full re-check' do
      expect { post comfy_recheck_admin_substack_subscriptions_path, headers: admin_headers }
        .to have_enqueued_job(CheckSubstackSubscriptionsJob).with(recheck: true)
    end

    context 'when a previous check stalled' do
      before { JobProgress.begin!('check_substack_subscriptions', label: 'Check', total: 10).update_columns(updated_at: 1.hour.ago) }

      it 'starts anyway' do
        expect { post comfy_recheck_admin_substack_subscriptions_path, headers: admin_headers }
          .to have_enqueued_job CheckSubstackSubscriptionsJob
      end
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_substack_subscriptions_path }

    it { expect(response).to redirect_to comfy_admin_sign_in_path }
  end

  describe 'POST unsubscribe' do
    let!(:subscription) { create :substack_subscription, :checked, publication_name: 'Quiet Eva', publication_subdomain: 'evawrites' }
    let(:client) { instance_double(Substack::Client, unsubscribe: {}) }
    let(:still_subscribed) { false }

    before do
      allow(Substack::Client).to receive(:new).and_return(client)
      allow(client).to receive(:publication_subscription).and_return('is_subscribed' => still_subscribed)
    end

    context 'from the Unsubscribe button (Turbo Stream)' do
      before { post comfy_unsubscribe_admin_substack_subscription_path(subscription), headers: admin_headers.merge('Accept' => 'text/vnd.turbo-stream.html') }

      it 'removes just that row' do
        expect(response.media_type).to eq 'text/vnd.turbo-stream.html'
        expect(response.body).to include %(action="remove" target="substack_subscription_#{subscription.id}")
        expect(SubstackSubscription.exists?(subscription.id)).to be false
      end

      context 'when Substack still lists it' do
        let(:still_subscribed) { true }

        it 'marks the row failed, with the reason, and keeps it' do
          expect(response.body).to include %(target="unsubscribe_substack_subscription_#{subscription.id}")
          expect(response.body).to include 'still lists you as subscribed'
          expect(SubstackSubscription.exists?(subscription.id)).to be true
        end
      end
    end

    context 'as a plain form post' do
      before { post comfy_unsubscribe_admin_substack_subscription_path(subscription), headers: admin_headers }

      it { expect(response).to redirect_to comfy_admin_substack_subscriptions_path }
      it { expect(flash[:success]).to include 'Quiet Eva' }
    end

    context 'without authentication' do
      before { post comfy_unsubscribe_admin_substack_subscription_path(subscription) }

      it 'does not touch Substack' do
        expect(response).to have_http_status :unauthorized
        expect(client).not_to have_received(:unsubscribe)
      end
    end
  end

  describe 'GET index Unsubscribe buttons' do
    let!(:free) { create :substack_subscription, :checked }
    let!(:paid) { create :substack_subscription, :checked, membership_state: 'subscribed' }

    before { get comfy_admin_substack_subscriptions_path(show: 'all'), headers: admin_headers }

    it { expect(response.body).to include comfy_unsubscribe_admin_substack_subscription_path(free) }
    it { expect(response.body).to_not include comfy_unsubscribe_admin_substack_subscription_path(paid) }
  end
end

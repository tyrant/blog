# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SubstackSubscriptionsController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET index' do
    let!(:candidate) { create :substack_subscription, :checked, publication_name: 'Quiet Eva', author_handle: 'eva' }
    let!(:follower) { create :substack_subscription, :checked, publication_name: 'Friendly Bob', follows_me: true }

    context 'by default' do
      before { get comfy_admin_substack_subscriptions_path, headers: http_auth_headers }

      it { expect(response).to have_http_status :success }
      it { expect(response.body).to include 'Quiet Eva' }
      it { expect(response.body).to include 'https://substack.com/@eva' }
      it { expect(response.body).to_not include 'Friendly Bob' }
      it { expect(response.body).to include '2 of 5,000 subscriptions' }
    end

    context 'showing all' do
      before { get comfy_admin_substack_subscriptions_path(show: 'all'), headers: http_auth_headers }

      it { expect(response.body).to include 'Friendly Bob' }
    end

    context 'searching' do
      before { get comfy_admin_substack_subscriptions_path(show: 'all', q: 'bob'), headers: http_auth_headers }

      it { expect(response.body).to_not include 'Quiet Eva' }
    end

    context 'while a check is running' do
      before do
        JobProgress.begin!('check_substack_subscriptions', label: 'Check', total: 10)
        get comfy_admin_substack_subscriptions_path, headers: http_auth_headers
      end

      it { expect(response.body).to include 'Checking: 0 of 10' }
    end

    context 'with nothing imported' do
      before do
        SubstackSubscription.delete_all
        get comfy_admin_substack_subscriptions_path, headers: http_auth_headers
      end

      it { expect(response.body).to include 'No subscriptions imported yet' }
    end

    context 'more than one page' do
      before do
        50.times { create :substack_subscription, :checked, publication_name: 'Filler' }
        get comfy_admin_substack_subscriptions_path, headers: http_auth_headers
      end

      it { expect(response).to have_http_status :success }
    end
  end

  describe 'POST import' do
    it 'enqueues an import' do
      expect { post comfy_import_admin_substack_subscriptions_path, headers: http_auth_headers }
        .to have_enqueued_job ImportSubstackSubscriptionsJob
    end

    context 'while a check is running' do
      before { JobProgress.begin!('check_substack_subscriptions', label: 'Check', total: 10) }

      it 'refuses' do
        expect { post comfy_import_admin_substack_subscriptions_path, headers: http_auth_headers }
          .to_not have_enqueued_job ImportSubstackSubscriptionsJob
      end
    end
  end

  describe 'POST recheck' do
    it 'enqueues a full re-check' do
      expect { post comfy_recheck_admin_substack_subscriptions_path, headers: http_auth_headers }
        .to have_enqueued_job(CheckSubstackSubscriptionsJob).with(recheck: true)
    end

    context 'when a previous check stalled' do
      before { JobProgress.begin!('check_substack_subscriptions', label: 'Check', total: 10).update_columns(updated_at: 1.hour.ago) }

      it 'starts anyway' do
        expect { post comfy_recheck_admin_substack_subscriptions_path, headers: http_auth_headers }
          .to have_enqueued_job CheckSubstackSubscriptionsJob
      end
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_substack_subscriptions_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

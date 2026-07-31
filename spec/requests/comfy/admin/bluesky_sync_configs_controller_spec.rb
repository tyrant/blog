# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::BlueskySyncConfigsController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET edit' do
    before { get edit_comfy_admin_bluesky_sync_config_path, headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'Bluesky Sync Settings' }
  end

  describe 'PATCH update' do
    context 'with valid credentials' do
      before do
        patch comfy_admin_bluesky_sync_config_path,
          params: { bluesky_sync_config: { handle: 'me.bsky.social', app_password: 'abcd-efgh', lead: 'New post' } },
          headers: http_auth_headers
      end

      it { expect(response).to redirect_to edit_comfy_admin_bluesky_sync_config_path }
      it { expect(BlueskySyncConfig.instance.handle).to eq 'me.bsky.social' }
      it { expect(BlueskySyncConfig.instance.app_password).to eq 'abcd-efgh' }
      it { expect(BlueskySyncConfig.instance.lead).to eq 'New post' }
    end

    context 'a blank app_password keeps the stored one' do
      before do
        BlueskySyncConfig.instance.update!(handle: 'me.bsky.social', app_password: 'saved-pw')
        patch comfy_admin_bluesky_sync_config_path,
          params: { bluesky_sync_config: { handle: 'me.bsky.social', app_password: '', lead: 'Edited' } },
          headers: http_auth_headers
      end

      it { expect(BlueskySyncConfig.instance.app_password).to eq 'saved-pw' }
      it { expect(BlueskySyncConfig.instance.lead).to eq 'Edited' }
    end

    context 'missing credentials' do
      before do
        patch comfy_admin_bluesky_sync_config_path,
          params: { bluesky_sync_config: { handle: '', app_password: '' } },
          headers: http_auth_headers
      end

      it { expect(response).to have_http_status :success }
      it { expect(response.body).to include 'Could not save' }
    end
  end

  describe 'without authentication' do
    before { get edit_comfy_admin_bluesky_sync_config_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

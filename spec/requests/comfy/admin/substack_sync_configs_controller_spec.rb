# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SubstackSyncConfigsController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET edit' do
    before { get edit_comfy_admin_substack_sync_config_path, headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'Substack Sync Settings' }
  end

  describe 'PATCH update' do
    context 'with valid params' do
      before do
        patch comfy_admin_substack_sync_config_path,
          params: { substack_sync_config: { subtitle: 'New sub', footer_json_text: '[{"type":"button"}]' } },
          headers: http_auth_headers
      end

      it { expect(response).to redirect_to edit_comfy_admin_substack_sync_config_path }
      it { expect(SubstackSyncConfig.instance.subtitle).to eq 'New sub' }
      it { expect(SubstackSyncConfig.instance.footer_json).to eq [{ 'type' => 'button' }] }
    end

    context 'with invalid footer JSON' do
      before do
        patch comfy_admin_substack_sync_config_path,
          params: { substack_sync_config: { subtitle: 'x', footer_json_text: 'not json' } },
          headers: http_auth_headers
      end

      it { expect(response).to have_http_status :success }
      it { expect(response.body).to include 'must be valid JSON' }
    end
  end

  describe 'POST recapture' do
    before do
      allow(Substack::TemplateCapturer).to receive(:execute).and_return([{ 'type' => 'button' }])
      post recapture_comfy_admin_substack_sync_config_path,
        params: { reference_draft_id: '999' }, headers: http_auth_headers
    end

    it { expect(response).to redirect_to edit_comfy_admin_substack_sync_config_path }

    it 'invokes the capturer with the given draft id' do
      expect(Substack::TemplateCapturer).to have_received(:execute).with(draft_id: '999')
    end
  end

  describe 'without authentication' do
    before { get edit_comfy_admin_substack_sync_config_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SolidQueueController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET show' do
    before { get comfy_admin_solid_queue_path, headers: http_auth_headers }

    it { expect(response).to have_http_status :success }

    it 'renders an iframe' do
      expect(response.body).to include '<iframe'
    end

    it 'points the iframe at the mounted jobs dashboard' do
      expect(response.body).to match(/<iframe[^>]*src=['"]\/admin\/jobs['"]/)
    end

    it 'keeps the ComfyAdmin nav (SolidQueue link now targets this page)' do
      expect(response.body).to include comfy_admin_solid_queue_path
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_solid_queue_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

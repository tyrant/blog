# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::Cms::SitesController', type: :request do
  let!(:site) { create(:site) }

  before { reset_cms_config }

  describe 'GET /admin/sites' do
    it 'returns success with authentication' do
      get comfy_admin_cms_sites_path, headers: http_auth_headers
      expect(response).to have_http_status(:success)
    end

    it 'requires authentication' do
      get comfy_admin_cms_sites_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /admin/sites/new' do
    it 'returns success' do
      get new_comfy_admin_cms_site_path, headers: http_auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /admin/sites' do
    let(:valid_params) do
      {
        site: {
          label: 'New Site',
          identifier: 'new-site',
          hostname: 'new-site.host'
        }
      }
    end

    it 'creates a new site' do
      expect {
        post comfy_admin_cms_sites_path, params: valid_params, headers: http_auth_headers
      }.to change { Comfy::Cms::Site.count }.by(1)
    end

    it 'redirects after creation' do
      post comfy_admin_cms_sites_path, params: valid_params, headers: http_auth_headers
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /admin/sites/:id/edit' do
    it 'returns success' do
      get edit_comfy_admin_cms_site_path(site), headers: http_auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /admin/sites/:id' do
    let(:update_params) do
      { site: { label: 'Updated Site' } }
    end

    it 'updates the site' do
      patch comfy_admin_cms_site_path(site), params: update_params, headers: http_auth_headers
      expect(site.reload.label).to eq('Updated Site')
    end
  end

  describe 'DELETE /admin/sites/:id' do
    it 'destroys the site' do
      expect {
        delete comfy_admin_cms_site_path(site), headers: http_auth_headers
      }.to change { Comfy::Cms::Site.count }.by(-1)
    end
  end
end

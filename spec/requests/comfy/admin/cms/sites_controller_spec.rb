# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::Cms::SitesController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET /admin/sites' do
    context 'with authentication' do
      before { get comfy_admin_cms_sites_path, headers: http_auth_headers }

      it { expect(response).to have_http_status :success }
    end

    context 'without authentication' do
      before { get comfy_admin_cms_sites_path }

      it { expect(response).to have_http_status :unauthorized }
    end
  end

  describe 'GET /admin/sites/new' do
    before { get new_comfy_admin_cms_site_path, headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
  end

  describe 'POST /admin/sites' do
    let(:valid_params) { { site: { label: 'New Site', identifier: 'new-site', hostname: 'new-site.host' } } }

    it { 
      expect { post comfy_admin_cms_sites_path, params: valid_params, headers: http_auth_headers }
        .to change { Comfy::Cms::Site.count }
        .by 1
    }

    context 'after creation' do
      before { post comfy_admin_cms_sites_path, params: valid_params, headers: http_auth_headers }

      it { expect(response).to have_http_status :redirect }
    end
  end

  describe 'GET /admin/sites/:id/edit' do
    before { get edit_comfy_admin_cms_site_path(site), headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
  end

  describe 'PATCH /admin/sites/:id' do
    let(:update_params) { { site: { label: 'Updated Site' } } }

    before {
      patch comfy_admin_cms_site_path(site), params: update_params, headers: http_auth_headers
    }

    it { expect(site.reload.label).to eq 'Updated Site' }
  end

  describe 'DELETE /admin/sites/:id' do
    it { 
      expect { delete comfy_admin_cms_site_path(site), headers: http_auth_headers }
        .to change { Comfy::Cms::Site.count }
        .by -1
    }
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::TagsController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET index' do
    before do
      Tag.create!(name: 'writing', substack_tag_id: 'uuid-1')
      get comfy_admin_tags_path, headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'writing' }
  end

  describe 'POST create' do
    it 'creates a tag' do
      expect { post comfy_admin_tags_path, params: { tag: { name: 'comedy' } }, headers: http_auth_headers }
        .to change(Tag, :count).by(1)
    end

    it 're-renders on a blank name' do
      post comfy_admin_tags_path, params: { tag: { name: '' } }, headers: http_auth_headers
      expect(response).to have_http_status :success
    end
  end

  describe 'PATCH update' do
    let!(:tag) { Tag.create!(name: 'comdey') }

    it 'renames the tag' do
      patch comfy_admin_tag_path(tag), params: { tag: { name: 'comedy' } }, headers: http_auth_headers
      expect(tag.reload.name).to eq 'comedy'
    end
  end

  describe 'DELETE destroy' do
    let!(:tag) { Tag.create!(name: 'comedy', substack_tag_id: 'uuid-1') }
    let!(:post_record) { create :post, site: site }

    before do
      allow(Substack::TagMirror).to receive(:unassign)
      BlogPostTag.without_mirror { post_record.tags << tag }
    end

    it 'deletes the tag' do
      expect { delete comfy_admin_tag_path(tag), headers: http_auth_headers }.to change(Tag, :count).by(-1)
    end

    it 'does not bulk-unassign the tag on Substack' do
      delete comfy_admin_tag_path(tag), headers: http_auth_headers
      expect(Substack::TagMirror).to_not have_received(:unassign)
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_tags_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

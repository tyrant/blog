# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SubstackUsersController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET index' do
    let!(:eva) { create :substack_user, name: 'Eva Solen', handle: 'evasolen' }

    context 'unfiltered' do
      before { get comfy_admin_substack_users_path, headers: http_auth_headers }

      it { expect(response).to have_http_status :success }
      it { expect(response.body).to include 'Eva Solen' }
      it { expect(response.body).to include 'https://substack.com/@evasolen' }
    end

    context 'searching' do
      before do
        create :substack_user, name: 'Bob', handle: 'bob'
        get comfy_admin_substack_users_path(q: 'solen'), headers: http_auth_headers
      end

      it { expect(response.body).to include 'Eva Solen' }
      it { expect(response.body).to_not include '@bob' }
    end

    context 'more than one page' do
      before do
        21.times { |i| create :substack_user, name: "Reader #{format('%02d', i)}" }
        get comfy_admin_substack_users_path, headers: http_auth_headers
      end

      it { expect(response.body).to_not include 'Reader 20' }
    end
  end

  describe 'GET new' do
    before { get new_comfy_admin_substack_user_path, headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
  end

  describe 'POST create' do
    it 'creates a user' do
      expect { post comfy_admin_substack_users_path, params: { substack_user: { name: 'Eva', handle: '@eva', user_id: '7' } }, headers: http_auth_headers }
        .to change(SubstackUser, :count).by(1)
    end

    it 're-renders when nothing identifies the user' do
      post comfy_admin_substack_users_path, params: { substack_user: { name: '', handle: '', user_id: '' } }, headers: http_auth_headers
      expect(response.body).to include 'Needs a user id, handle or name'
    end
  end

  describe 'GET edit' do
    let!(:user) { create :substack_user, name: 'Eva' }

    before do
      SubstackQuotation.create!(quotation: 'a lovely blurb', comment_url: 'https://x/comment/1', substack_user: user)
      get edit_comfy_admin_substack_user_path(user), headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'a lovely blurb' }
  end

  describe 'PATCH update' do
    let!(:user) { create :substack_user, name: 'Eva' }

    it 'renames the user' do
      patch comfy_admin_substack_user_path(user), params: { substack_user: { name: 'Eva Solen' } }, headers: http_auth_headers
      expect(user.reload.name).to eq 'Eva Solen'
    end

    it 're-renders on a taken handle' do
      create :substack_user, handle: 'bob'
      patch comfy_admin_substack_user_path(user), params: { substack_user: { handle: 'BOB' } }, headers: http_auth_headers
      expect(response.body).to include 'Handle has already been taken'
    end
  end

  describe 'DELETE destroy' do
    let!(:user) { create :substack_user }
    let!(:quotation) { SubstackQuotation.create!(quotation: 'q', comment_url: 'https://x/comment/1', substack_user: user) }

    it 'deletes the user' do
      expect { delete comfy_admin_substack_user_path(user), headers: http_auth_headers }.to change(SubstackUser, :count).by(-1)
    end

    it 'keeps their quotations, unlinked' do
      delete comfy_admin_substack_user_path(user), headers: http_auth_headers
      expect(quotation.reload.substack_user).to be_nil
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_substack_users_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

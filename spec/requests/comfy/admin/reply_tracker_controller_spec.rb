# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::ReplyTrackerController', type: :request do
  let!(:site) { create :site }
  let(:params) { { comment_url: 'https://x/comment/1' } }
  let(:resolved) do
    Substack::ReplyResolver::Result.new(target_url: 'https://x/p/y', author_name: 'Cory',
                                        author_handle: 'coryalthoff', author_user_id: 99,
                                        replied_at: '2026-07-10T00:00:00Z')
  end

  before { reset_cms_config }

  describe 'GET index' do
    before do
      SubstackReply.create!(target_url: 'https://x/p/y', comment_url: 'https://x/comment/1',
                            author_name: 'Cory', author_handle: 'coryalthoff', replied_at: Time.current)
      get comfy_admin_reply_tracker_path, headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'Reply Tracker' }
    it { expect(response.body).to include 'coryalthoff' }
  end

  describe 'POST log' do
    context 'when the reply resolves' do
      before { allow(Substack::ReplyResolver).to receive(:execute).and_return(resolved) }

      it 'logs a reply record' do
        expect { post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers }
          .to change(SubstackReply, :count).by(1)
      end

      it 'stores the resolved target and author' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(SubstackReply.last).to have_attributes(target_url: 'https://x/p/y', author_handle: 'coryalthoff')
      end

      it 'resolves from the reply url' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(Substack::ReplyResolver).to have_received(:execute).with(reply_url: 'https://x/comment/1')
      end

      it 'redirects back to the tracker' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(response).to redirect_to(comfy_admin_reply_tracker_path)
      end
    end

    context 'when resolution fails' do
      before { allow(Substack::ReplyResolver).to receive(:execute).and_raise('bad url') }

      it 'creates no record' do
        expect { post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers }
          .to_not change(SubstackReply, :count)
      end

      it 'redirects back' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(response).to redirect_to comfy_admin_reply_tracker_path
      end
    end
  end

  describe 'DELETE destroy' do
    let!(:reply) do
      SubstackReply.create!(target_url: 'https://x/p/y', comment_url: 'https://x/comment/1',
                            author_handle: 'coryalthoff', replied_at: Time.current)
    end

    it 'deletes the reply' do
      expect { delete comfy_admin_reply_tracker_delete_path(reply), headers: http_auth_headers }
        .to change(SubstackReply, :count).by(-1)
    end

    it 'redirects back to the tracker' do
      delete comfy_admin_reply_tracker_delete_path(reply), headers: http_auth_headers
      expect(response).to redirect_to comfy_admin_reply_tracker_path
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_reply_tracker_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

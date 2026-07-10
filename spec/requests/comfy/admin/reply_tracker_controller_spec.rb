# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::ReplyTrackerController', type: :request do
  let!(:site) { create :site }
  let(:params) { { target_url: 'https://x/p/y', comment_url: 'https://x/comment/1' } }

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
    context 'when the target resolves' do
      before do
        allow(Substack::TargetResolver).to receive(:execute)
          .and_return('name' => 'Cory', 'handle' => 'coryalthoff', 'user_id' => 99)
      end

      it 'logs a reply record' do
        expect { post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers }
          .to change(SubstackReply, :count).by(1)
      end

      it 'stores the resolved author' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(SubstackReply.last.author_handle).to eq 'coryalthoff'
      end

      it 'resolves from the target url' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(Substack::TargetResolver).to have_received(:execute).with(url: 'https://x/p/y')
      end

      it { post(comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers) && (expect(response).to redirect_to(comfy_admin_reply_tracker_path)) }
    end

    context 'when resolution fails' do
      before { allow(Substack::TargetResolver).to receive(:execute).and_raise('bad url') }

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

  describe 'without authentication' do
    before { get comfy_admin_reply_tracker_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

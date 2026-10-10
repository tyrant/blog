# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::ReplyTrackerController', type: :request do
  let!(:site) { create :site }
  let(:params) { { comment_url: 'https://x/comment/1' } }
  let(:resolved) do
    Substack::ReplyResolver::Result.new(target_url: 'https://x/p/y', author_name: 'Cory',
                                        author_handle: 'coryalthoff', author_user_id: 99,
                                        replied_at: '2026-07-10T00:00:00Z',
                                        target_preview: 'A Post Title', reply_preview: 'My reply text',
                                        ancestor_path: '10.20')
  end

  before { reset_cms_config }

  describe 'GET index' do
    before do
      SubstackReply.create!(target_url: 'https://x/p/y', comment_url: 'https://x/comment/1',
                            substack_user: cory, replied_at: Time.current)
      get comfy_admin_reply_tracker_path, headers: http_auth_headers
    end

    let(:cory) { create :substack_user, name: 'Cory', handle: 'coryalthoff' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'Reply Tracker' }
    it { expect(response.body).to include 'coryalthoff' }
    it { expect(response.body).to include %(href="#{edit_comfy_admin_substack_user_path(cory)}">Comfy</a>) }
    it { expect(response.body).to include %(href="https://substack.com/@coryalthoff">Substack</a>) }
  end

  describe 'GET index with a reply to someone else in the thread' do
    before do
      SubstackReply.create!(target_url: 'https://x/p/y', comment_url: 'https://x/p/y/comment/100',
                            substack_user: create(:substack_user, handle: 'coryalthoff'), replied_at: 1.hour.ago)
      SubstackReply.create!(target_url: 'https://x/p/y/comment/150', comment_url: 'https://x/p/y/comment/200', ancestor_path: '100',
                            substack_user: eva, replied_at: Time.current)
      get comfy_admin_reply_tracker_path, headers: http_auth_headers
    end

    let(:eva) { create :substack_user, handle: 'eva' }

    it { expect(response.body).to include %(href="#{edit_comfy_admin_substack_user_path(eva)}">Comfy</a>) }
    it { expect(response.body).to include %(href="https://substack.com/@eva">Substack</a>) }
  end

  describe 'GET index with a username search' do
    before do
      SubstackReply.create!(target_url: 't1', comment_url: 'https://x/p/y/comment/1', substack_user: create(:substack_user, handle: 'coryalthoff'), replied_at: Time.current)
      SubstackReply.create!(target_url: 't2', comment_url: 'https://x/p/y/comment/2', substack_user: create(:substack_user, handle: 'someoneelse'), replied_at: Time.current)
      get comfy_admin_reply_tracker_path(q: 'cory'), headers: http_auth_headers
    end

    it { expect(response.body).to include 'coryalthoff' }
    it { expect(response.body).to_not include 'someoneelse' }
  end

  describe 'POST log' do
    context 'when the reply resolves' do
      before { allow(Substack::ReplyResolver).to receive(:execute).and_return(resolved) }

      it 'logs a reply record' do
        expect { post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers }
          .to change(SubstackReply, :count).by(1)
      end

      it 'stores the resolved target, author and previews' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(SubstackReply.last).to have_attributes(target_url: 'https://x/p/y',
                                                      target_preview: 'A Post Title', reply_preview: 'My reply text')
      end

      it 'links the replied-to account' do
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
        expect(SubstackReply.last.substack_user).to have_attributes(user_id: 99, handle: 'coryalthoff', name: 'Cory')
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

    context 'when the reply is already logged' do
      before do
        SubstackReply.create!(target_url: 't', comment_url: 'https://x/comment/1', replied_at: Time.current)
        allow(Substack::ReplyResolver).to receive(:execute)
        post comfy_admin_reply_tracker_log_path, params: params, headers: http_auth_headers
      end

      it 'does not create a duplicate' do
        expect(SubstackReply.where(comment_url: 'https://x/comment/1').count).to eq 1
      end

      it 'does not call the resolver' do
        expect(Substack::ReplyResolver).to_not have_received(:execute)
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
                            substack_user: create(:substack_user, handle: 'coryalthoff'), replied_at: Time.current)
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

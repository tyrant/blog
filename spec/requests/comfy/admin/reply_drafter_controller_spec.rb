# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::ReplyDrafterController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET show' do
    before { get comfy_admin_reply_drafter_path, headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'Reply Drafter' }
    it { expect(response.body).to include 'reply-generate' }
  end

  describe 'POST generate' do
    let(:replies) { [{ 'stance' => 'agree', 'text' => 'Nice.' }] }

    context 'when generation succeeds' do
      before do
        allow(Substack::ReplyGenerator).to receive(:execute).and_return(replies)
        post comfy_admin_reply_drafter_generate_path, params: { url: 'https://x/p/y' }, headers: http_auth_headers
      end

      it { expect(response).to have_http_status :success }
      it { expect(JSON.parse(response.body)['replies']).to eq replies }

      it 'passes the url to the generator' do
        expect(Substack::ReplyGenerator).to have_received(:execute).with(url: 'https://x/p/y')
      end
    end

    context 'when generation raises' do
      before do
        allow(Substack::ReplyGenerator).to receive(:execute).and_raise('boom')
        post comfy_admin_reply_drafter_generate_path, params: { url: 'https://x/p/y' }, headers: http_auth_headers
      end

      it { expect(response).to have_http_status :unprocessable_content }
      it { expect(JSON.parse(response.body)['error']).to eq 'boom' }
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_reply_drafter_path }

    it { expect(response).to have_http_status :unauthorized }
  end
end

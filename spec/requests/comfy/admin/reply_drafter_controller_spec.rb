# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::ReplyDrafterController', type: :request do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'GET show' do
    before { get comfy_admin_reply_drafter_path, headers: admin_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'Reply Drafter' }
    it { expect(response.body).to include 'reply-generate' }
  end

  describe 'POST generate' do
    let(:replies) { [{ 'stance' => 'agree', 'text' => 'Nice.' }] }
    let(:result) do
      Substack::ReplyGenerator::Result.new(replies: replies, post_contains_instructions: true, problems: ['Dropped a reply that contains a link.'],
                                           attempts: 2, input_tokens: 900, output_tokens: 300, latency_ms: 4200)
    end

    context 'when generation succeeds' do
      before do
        allow(Substack::ReplyGenerator).to receive(:execute).and_return(result)
        post comfy_admin_reply_drafter_generate_path,
             params: { url: 'https://x/p/y', instructions: 'Be dry.', count: '3', split: 'disagree', length: '1', model: 'claude-opus-4-8' },
             headers: admin_headers
      end

      it { expect(response).to have_http_status :success }
      it { expect(JSON.parse(response.body)['replies']).to eq replies }
      it { expect(JSON.parse(response.body)['post_contains_instructions']).to be true }
      it { expect(JSON.parse(response.body)['problems']).to eq ['Dropped a reply that contains a link.'] }
      it { expect(JSON.parse(response.body).values_at('attempts', 'input_tokens', 'output_tokens', 'latency_ms')).to eq [2, 900, 300, 4200] }

      it 'passes the url and knobs to the generator' do
        expect(Substack::ReplyGenerator).to have_received(:execute)
          .with(url: 'https://x/p/y', instructions: 'Be dry.', count: 3, split: 'disagree', length: '1', model: 'claude-opus-4-8')
      end

      it 'persists the settings as the new defaults' do
        config = ReplyDrafterConfig.instance
        expect([config.instructions, config.count, config.split, config.length, config.model])
          .to eq ['Be dry.', 3, 'disagree', '1', 'claude-opus-4-8']
      end
    end

    context 'when generation raises' do
      before do
        allow(Substack::ReplyGenerator).to receive(:execute).and_raise('boom')
        post comfy_admin_reply_drafter_generate_path, params: { url: 'https://x/p/y' }, headers: admin_headers
      end

      it { expect(response).to have_http_status :unprocessable_content }
      it { expect(JSON.parse(response.body)['error']).to eq 'boom' }
    end
  end

  describe 'without authentication' do
    before { get comfy_admin_reply_drafter_path }

    it { expect(response).to redirect_to comfy_admin_sign_in_path }
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Anthropic::Client do
  subject(:client) { described_class.new(api_key: key) }

  let(:key) { 'sk-test' }

  describe '#configured?' do
    it { expect(client.configured?).to be true }

    context 'without a key' do
      let(:key) { nil }
      it { expect(client.configured?).to be false }
    end
  end

  describe '#complete' do
    let!(:stub) do
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .with(headers: { 'x-api-key' => 'sk-test', 'anthropic-version' => '2023-06-01' },
              body: hash_including('model' => 'claude-sonnet-5', 'system' => 'sys'))
        .to_return(status: 200, body: { content: [{ type: 'text', text: 'hello' }] }.to_json)
    end

    it 'returns the assistant text' do
      expect(client.complete(system: 'sys', prompt: 'hi')).to eq 'hello'
    end

    it 'posts the prompt as a user message' do
      client.complete(system: 'sys', prompt: 'hi')
      expect(stub).to have_been_requested
    end

    context 'without a key' do
      let(:key) { nil }
      it { expect { client.complete(system: 's', prompt: 'p') }.to raise_error(Anthropic::Client::NotConfigured) }
    end

    context 'on an API error' do
      before do
        stub_request(:post, 'https://api.anthropic.com/v1/messages')
          .to_return(status: 429, body: { error: { message: 'rate limited' } }.to_json)
      end

      it { expect { client.complete(system: 's', prompt: 'p') }.to raise_error(Anthropic::Client::Error, /rate limited/) }
    end
  end
end

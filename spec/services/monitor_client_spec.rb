# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MonitorClient do
  before { allow(ENV).to receive(:[]).and_call_original }

  describe '.report with an API key set' do
    before { allow(ENV).to receive(:[]).with('MONITOR_API_KEY').and_return('test-key') }

    let!(:stub) do
      stub_request(:post, 'https://monitor.mikeyclarke.co.nz/api/run')
        .with(headers: { 'X-API-Key' => 'test-key', 'Content-Type' => 'application/json' })
        .to_return(status: 200, body: '{"ok":true}')
    end

    it 'posts the run report' do
      described_class.report(script: 'substack_blizzard', status: 'success', processed: 1)
      expect(stub).to have_been_requested
    end

    it 'sends the given fields in the JSON body' do
      described_class.report(script: 'substack_blizzard', status: 'crashed', failed: 1, errors: ['boom'])
      expect(stub.with { |req|
        body = JSON.parse(req.body)
        body['script'] == 'substack_blizzard' && body['status'] == 'crashed' &&
          body['failed'] == 1 && body['errors'] == ['boom']
      }).to have_been_requested
    end
  end

  describe '.report without an API key set' do
    before { allow(ENV).to receive(:[]).with('MONITOR_API_KEY').and_return(nil) }

    it 'does not make a request' do
      described_class.report(script: 'substack_blizzard', status: 'success')
      expect(WebMock).to_not have_requested(:post, 'https://monitor.mikeyclarke.co.nz/api/run')
    end
  end

  describe '.report when the request errors' do
    before do
      allow(ENV).to receive(:[]).with('MONITOR_API_KEY').and_return('test-key')
      stub_request(:post, 'https://monitor.mikeyclarke.co.nz/api/run').to_timeout
    end

    it 'does not raise' do
      expect { described_class.report(script: 'substack_blizzard', status: 'success') }.to_not raise_error
    end
  end
end

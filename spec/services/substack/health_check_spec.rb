# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::HealthCheck do
  subject(:result) { described_class.execute(client: client) }

  let(:client) { instance_double(Substack::Client) }

  context 'when the cookie is valid' do
    before { allow(client).to receive(:verify_session).and_return(true) }

    it { expect(result.status).to eq :ok }
    it { expect(result).to be_ok }

    it 'records a healthy, freshly-checked session' do
      result
      expect(SubstackSyncConfig.instance).to have_attributes(session_healthy: true, session_checked_at: be_present)
    end
  end

  context 'when the cookie is rejected' do
    before { allow(client).to receive(:verify_session).and_raise(Substack::Client::AuthError, 'dead cookie') }

    it { expect(result.status).to eq :auth_failed }

    it 'records an unhealthy session' do
      result
      expect(SubstackSyncConfig.instance.reload.session_healthy?).to be false
    end
  end

  context 'when the check is inconclusive (non-auth error)' do
    before do
      SubstackSyncConfig.instance.update_columns(session_healthy: true, session_error: nil)
      allow(client).to receive(:verify_session).and_raise(Substack::Client::Error, 'timeout')
    end

    it { expect(result.status).to eq :inconclusive }

    it 'leaves the stored status unchanged' do
      result
      expect(SubstackSyncConfig.instance.reload.session_healthy?).to be true
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackPostSyncJob do
  before { allow(Substack::PostSyncer).to receive(:execute) }

  it 'delegates to the post syncer' do
    described_class.perform_now(7)
    expect(Substack::PostSyncer).to have_received(:execute).with(post_id: 7)
  end
end

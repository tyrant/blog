# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlueskyPostSyncJob do
  before { allow(Bluesky::PostSyncer).to receive(:execute) }

  it 'delegates to the post syncer' do
    described_class.perform_now(7)
    expect(Bluesky::PostSyncer).to have_received(:execute).with(post_id: 7)
  end
end

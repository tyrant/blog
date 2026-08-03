# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackPostSyncJob do
  before { allow(Substack::PostSyncer).to receive(:execute) }

  it 'delegates to the post syncer' do
    described_class.perform_now(7)
    expect(Substack::PostSyncer).to have_received(:execute).with(post_id: 7)
  end

  describe 'concurrency' do
    it 'runs only one Substack sync at a time' do
      expect(described_class.concurrency_limit).to eq 1
    end

    it 'shares one concurrency key across posts so syncs never overlap' do
      expect(described_class.new(1).concurrency_key).to eq described_class.new(2).concurrency_key
    end
  end
end

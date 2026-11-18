# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScanSubstackEngagementJob do
  before { allow(Substack::EngagementScanner).to receive(:execute) }

  it 'scans everything the first time' do
    described_class.perform_now
    expect(Substack::EngagementScanner).to have_received(:execute).with(since: nil, progress: an_instance_of(JobProgress))
    expect(JobProgress.find_by(key: 'scan_substack_engagement').status).to eq 'finished'
  end

  context 'after a finished scan' do
    let(:last) { Time.zone.parse('2026-11-01 04:00') }

    before { JobProgress.create!(key: 'scan_substack_engagement', label: 'x', total: 1, completed: 1, status: 'finished', started_at: last) }

    it 'rescans from 60 days before it' do
      described_class.perform_now
      expect(Substack::EngagementScanner).to have_received(:execute).with(since: last - 60.days, progress: anything)
    end

    it 'rescans everything when asked for a full scan' do
      described_class.perform_now(full: true)
      expect(Substack::EngagementScanner).to have_received(:execute).with(since: nil, progress: anything)
    end
  end
end

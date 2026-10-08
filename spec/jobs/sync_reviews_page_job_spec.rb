# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncReviewsPageJob, type: :job do
  before { allow(Substack::ReviewsPageSyncer).to receive(:execute) }

  it 'runs the reviews page syncer for every page by default' do
    described_class.new.perform
    expect(Substack::ReviewsPageSyncer).to have_received(:execute).with(page: nil)
  end

  it 'runs it for one page when given' do
    described_class.new.perform(4)
    expect(Substack::ReviewsPageSyncer).to have_received(:execute).with(page: 4)
  end
end

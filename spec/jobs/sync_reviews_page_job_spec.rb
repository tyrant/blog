# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncReviewsPageJob, type: :job do
  before { allow(Substack::ReviewsPageSyncer).to receive(:execute) }

  it 'runs the reviews page syncer' do
    described_class.new.perform
    expect(Substack::ReviewsPageSyncer).to have_received(:execute)
  end
end

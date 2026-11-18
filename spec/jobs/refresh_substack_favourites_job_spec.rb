# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshSubstackFavouritesJob do
  before { allow(Substack::FavouritesRefresher).to receive(:execute) }

  it 'refreshes the feed with progress' do
    described_class.perform_now
    expect(Substack::FavouritesRefresher).to have_received(:execute).with(progress: an_instance_of(JobProgress))
    expect(JobProgress.find_by(key: 'refresh_substack_favourites').status).to eq 'finished'
  end
end

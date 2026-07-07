# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshNoteLikesJob do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:substack) { create :category, site: site, label: 'Substack' }
  let!(:other) { create :category, site: site, label: 'Whimsy' }
  let!(:substack_cat) { create :categorization, category: substack, categorized: post }
  let!(:other_cat) { create :categorization, category: other, categorized: post }

  before { allow_any_instance_of(described_class).to receive(:sleep) }

  it 'refreshes each Substack categorization' do
    expect(Substack::Blizzard::LikesRefresher).to receive(:execute).with(hash_including(categorization: substack_cat, commit: true))
    described_class.perform_now
  end

  it 'skips non-Substack categorizations' do
    allow(Substack::Blizzard::LikesRefresher).to receive(:execute)
    described_class.perform_now
    expect(Substack::Blizzard::LikesRefresher).to_not have_received(:execute).with(hash_including(categorization: other_cat))
  end

  it 'continues past a categorization that raises' do
    allow(Substack::Blizzard::LikesRefresher).to receive(:execute).and_raise('boom')
    expect { described_class.perform_now }.to_not raise_error
  end
end

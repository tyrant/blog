# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshNotePostLikesJob do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:substack) { create :category, site: site, label: 'Substack' }
  let!(:other) { create :category, site: site, label: 'Whimsy' }
  let!(:substack_cat) { create :categorization, category: substack, categorized: post }
  let!(:other_cat) { create :categorization, category: other, categorized: post }

  before { allow_any_instance_of(described_class).to receive(:sleep) }

  it 'refreshes each Substack categorization' do
    allow(Substack::Blizzard::LikesRefresher).to receive(:execute)
    described_class.perform_now
    expect(Substack::Blizzard::LikesRefresher).to have_received(:execute).with(hash_including(categorization: substack_cat, commit: true))
  end

  it 'also refreshes the unattached-notes pool (BlizzardScheduleConfig)' do
    allow(Substack::Blizzard::LikesRefresher).to receive(:execute)
    described_class.perform_now
    expect(Substack::Blizzard::LikesRefresher).to have_received(:execute).with(hash_including(categorization: BlizzardScheduleConfig.instance, commit: true))
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

  describe 'progress reporting' do
    before { allow(Substack::Blizzard::LikesRefresher).to receive(:execute) }

    it 'finishes the progress row' do
      described_class.perform_now
      expect(JobProgress.find_by(key: 'refresh_note_post_likes').status).to eq 'finished'
    end

    it 'advances once per Substack categorization, plus once for the unattached-notes pool' do
      described_class.perform_now
      expect(JobProgress.find_by(key: 'refresh_note_post_likes').completed).to eq 2
    end
  end
end

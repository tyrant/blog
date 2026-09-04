# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::LikesRefresher do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, data: data }

  let(:data) do
    { 'blizzard' => [
      { 'uid' => 'e0', 'text' => 'g0', 'body_json' => {}, 'notes' => [
        { 'url' => 'https://substack.com/@m/note/c-111', 'timestamp' => '2025-01-01T00:00:00Z' },
        { 'url' => 'https://substack.com/@m/note/c-222', 'timestamp' => '2025-02-01T00:00:00Z', 'likes' => 4 }
      ] }
    ] }
  end

  let(:client) { instance_double(Substack::Client) }

  before do
    allow(client).to receive(:get_note).with('111').and_return('comment' => { 'reaction_count' => 7 })
    allow(client).to receive(:get_note).with('222').and_return('comment' => { 'reaction_count' => 12 })
  end

  subject(:run) { described_class.execute(categorization: categorization, client: client) }

  it 'writes the fetched like count on each note' do
    run
    likes = categorization.reload.data['blizzard'][0]['notes'].map { |n| n['likes'] }
    expect(likes).to eq [7, 12]
  end

  it { expect(run.updated).to eq 2 }

  context 'a note that fails to fetch' do
    before { allow(client).to receive(:get_note).with('222').and_raise(Substack::Client::Error, 'gone') }

    it 'keeps the last-known likes rather than zeroing it' do
      run
      expect(categorization.reload.data['blizzard'][0]['notes'][1]['likes']).to eq 4
    end

    it { expect(run.failed).to eq 1 }
    it { expect(run.updated).to eq 1 }
  end

  context 'commit: false' do
    subject(:run) { described_class.execute(categorization: categorization, client: client, commit: false) }

    it 'does not persist' do
      run
      expect(categorization.reload.data['blizzard'][0]['notes'][0]['likes']).to be_nil
    end
  end

  describe 'post likes' do
    let!(:categorization) { create :categorization, category: category, categorized: post, url: 'https://mikeyclarke.substack.com/p/foo', data: data }

    before { allow(client).to receive(:get_post).with(categorization.url).and_return('reaction_count' => 30) }

    it 'stores the post reaction_count on the post' do
      run
      expect(post.reload.substack_likes).to eq 30
    end

    context 'commit: false' do
      subject(:run) { described_class.execute(categorization: categorization, client: client, commit: false) }
      it { run; expect(post.reload.substack_likes).to be_nil }
    end

    context 'the post fetch fails' do
      before { allow(client).to receive(:get_post).and_raise(Substack::Client::Error, 'gone') }
      it { expect { run }.to_not raise_error }
      it 'still records the note likes' do
        run
        expect(categorization.reload.data['blizzard'][0]['notes'][0]['likes']).to eq 7
      end
    end
  end

  describe 'against the BlizzardScheduleConfig singleton (unattached-notes pool)' do
    subject(:run) { described_class.execute(categorization: config, client: client) }

    let(:config) { BlizzardScheduleConfig.instance.tap { |c| c.update!(data: data) } }

    it 'writes the fetched like count on each note' do
      run
      likes = config.reload.data['blizzard'][0]['notes'].map { |n| n['likes'] }
      expect(likes).to eq [7, 12]
    end

    it 'does not attempt to refresh a post like count (no parent post)' do
      expect { run }.to_not raise_error
    end
  end
end

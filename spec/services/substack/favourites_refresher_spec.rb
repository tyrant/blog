# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::FavouritesRefresher do
  subject(:refresh) { described_class.execute(client: client, progress: progress) }

  let(:client) { instance_double(Substack::Client) }
  let(:progress) { JobProgress.begin!('refresh', label: 'Refresh', total: 0) }
  let!(:eva) { create :substack_user, user_id: 11, handle: 'eva', name: 'Eva', favourite: true }

  def note(id, date: 1.day.ago, user_id: 11, context: 'note', **extra)
    { 'type' => 'comment', 'context' => { 'type' => context },
      'comment' => { 'id' => id, 'user_id' => user_id, 'handle' => 'eva', 'body' => "  note #{id}\n body ", 'date' => date.iso8601 }.merge(extra) }
  end

  def post(id, byline: 11, date: 2.days.ago)
    { 'type' => 'post', 'context' => { 'type' => 'latest_post' },
      'post' => { 'id' => id, 'title' => 'A post', 'subtitle' => 'Sub', 'canonical_url' => "https://eva.substack.com/p/#{id}",
                  'post_date' => date.iso8601, 'publishedBylines' => [{ 'id' => byline }], 'reaction' => '❤', 'restacked' => true } }
  end

  let(:items) do
    [note(1, 'reaction' => '❤'), post(2), note(3, context: 'comment_restack'), note(4, user_id: 99),
     post(5, byline: 99), note(6, date: 40.days.ago)]
  end

  before do
    allow_any_instance_of(described_class).to receive(:sleep)
    allow(client).to receive(:profile_feed).with(11).and_return('items' => items)
  end

  it 'lists only their own recent posts and Notes' do
    expect(refresh[:added]).to eq 2
    expect(SubstackFavouriteItem.pluck(:entity_key)).to contain_exactly('c-1', 'p-2')
  end

  it 'records each item’s link, text and my reactions' do
    refresh
    expect(SubstackFavouriteItem.find_by(entity_key: 'c-1')).to have_attributes(
      kind: 'note', url: 'https://substack.com/@eva/note/c-1', excerpt: 'note 1 body', liked: true, restacked: false, substack_user: eva
    )
    expect(SubstackFavouriteItem.find_by(entity_key: 'p-2')).to have_attributes(
      kind: 'post', url: 'https://eva.substack.com/p/2', title: 'A post', excerpt: 'Sub', liked: true, restacked: true
    )
  end

  it 'updates existing items without undoing Done' do
    refresh
    SubstackFavouriteItem.find_by(entity_key: 'c-1').update!(dismissed_at: Time.current, liked: false)
    expect(described_class.execute(client: client)[:added]).to eq 0
    expect(SubstackFavouriteItem.find_by(entity_key: 'c-1')).to have_attributes(liked: true, dismissed_at: be_present)
  end

  it 'prunes old items' do
    SubstackFavouriteItem.create!(substack_user: eva, entity_key: 'c-0', kind: 'note', url: 'u', published_at: 90.days.ago)
    refresh
    expect(SubstackFavouriteItem.exists?(entity_key: 'c-0')).to be false
  end

  it 'reports progress' do
    refresh
    expect(progress.reload).to have_attributes(total: 1, completed: 1)
  end

  context 'with a favourite known only by handle' do
    let!(:eva) { create :substack_user, user_id: nil, handle: 'eva', name: nil, favourite: true }

    before { allow(client).to receive(:public_profile_by_handle).with('eva').and_return('id' => 11, 'handle' => 'eva', 'name' => 'Eva') }

    it 'looks up their id first, keeping them a favourite' do
      refresh
      expect(SubstackUser.with_handle('eva').sole).to have_attributes(user_id: 11, name: 'Eva', favourite: true)
      expect(SubstackFavouriteItem.count).to eq 2
    end
  end

  context 'with a favourite with neither id nor handle' do
    let!(:eva) { create :substack_user, user_id: nil, handle: nil, name: 'Eva', favourite: true }

    it { expect(refresh[:added]).to eq 0 }
  end

  context 'when a favourite’s feed fails' do
    before { allow(client).to receive(:profile_feed).and_raise(Substack::Client::NotFound, 'gone') }

    it 'records the failure and carries on' do
      expect(refresh[:failures]).to eq ['eva: gone']
    end
  end

  context 'when the session is rejected' do
    before { allow(client).to receive(:profile_feed).and_raise(Substack::Client::AuthError, 'expired') }

    it { expect { refresh }.to raise_error(Substack::Client::AuthError) }
  end
end

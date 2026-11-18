# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::EngagementScanner do
  subject(:scan) { described_class.execute(client: client, since: since, progress: progress) }

  let(:client) { instance_double(Substack::Client) }
  let(:since) { nil }
  let(:progress) { JobProgress.begin!('scan', label: 'Scan', total: 0) }
  let(:me) { 4619740 }

  let(:post) do
    { 'id' => 7, 'post_date' => '2026-10-01T00:00:00Z', 'comment_count' => 2, 'reaction_count' => 3, 'reaction' => '❤', 'restacks' => 1 }
  end
  let(:quiet_post) { { 'id' => 8, 'post_date' => '2026-09-01T00:00:00Z', 'comment_count' => 0, 'reaction_count' => 1, 'reaction' => '❤', 'restacks' => 0 } }

  def note_item(id, date, user_id: me, context: 'note', **counts)
    { 'type' => 'comment', 'context' => { 'type' => context, 'timestamp' => date },
      'comment' => { 'id' => id, 'user_id' => user_id, 'date' => date, 'reaction_count' => 0, 'restacks' => 0, 'children_count' => 0 }.merge(counts.transform_keys(&:to_s)) }
  end

  let(:note) { note_item(50, '2026-10-02T00:00:00Z', reaction_count: 1, restacks: 1, children_count: 2) }

  before do
    SubstackSyncConfig.instance.update!(author_id: me)
    allow_any_instance_of(described_class).to receive(:sleep)
    allow(client).to receive(:archive_page).with(nil).and_return('posts' => [post], 'nextCursor' => 'more')
    allow(client).to receive(:archive_page).with('more').and_return('posts' => [quiet_post], 'nextCursor' => nil)
    allow(client).to receive(:profile_feed).with(me, nil).and_return(
      'items' => [note, note_item(51, '2026-10-03T00:00:00Z', user_id: 9, context: 'comment_restack'), { 'type' => 'post', 'context' => {} }],
      'nextCursor' => nil
    )
    allow(client).to receive(:post_comments).with(7).and_return('comments' => [
      { 'user_id' => 1, 'handle' => 'eva', 'name' => 'Eva', 'date' => '2026-10-02T00:00:00Z',
        'children' => [{ 'user_id' => me, 'date' => '2026-10-03T00:00:00Z', 'children' => [] },
                       { 'user_id' => 2, 'deleted' => true, 'children' => [] }] }
    ])
    allow(client).to receive(:post_reactors).with(7).and_return([{ 'id' => me }, { 'id' => 1, 'name' => 'Eva' }, { 'id' => 3, 'name' => 'Cat' }])
    allow(client).to receive(:post_restackers).with(7).and_return([{ 'id' => 3, 'name' => 'Cat' }])
    allow(client).to receive(:note_reactors).with(50).and_return([{ 'id' => 1 }])
    allow(client).to receive(:note_restackers).with(50).and_return([{ 'id' => 3 }])
    allow(client).to receive(:note_replies).with(50, nil).and_return(
      'commentBranches' => [{ 'comment' => { 'user_id' => 1, 'name' => 'Eva', 'date' => '2026-10-04T00:00:00Z' },
                              'descendantComments' => [{ 'comment' => { 'user_id' => me } }] }],
      'nextCursor' => 'r2'
    )
    allow(client).to receive(:note_replies).with(50, 'r2').and_return(
      'commentBranches' => [{ 'comment' => { 'user_id' => 4, 'name' => 'Dee', 'date' => '2026-10-05T00:00:00Z' } }], 'nextCursor' => nil
    )
  end

  def engagements = SubstackEngagement.order(:user_id, :content_key, :kind).pluck(:user_id, :content_key, :kind)

  it 'records comments, likes and restacks on posts and likes, restacks and replies on my Notes, never mine' do
    scan
    expect(engagements).to eq [
      [1, 'c-50', 'like'], [1, 'c-50', 'reply'], [1, 'p-7', 'comment'], [1, 'p-7', 'like'],
      [3, 'c-50', 'restack'], [3, 'p-7', 'like'], [3, 'p-7', 'restack'],
      [4, 'c-50', 'reply']
    ]
  end

  it 'keeps commenters’ handles and names' do
    scan
    expect(SubstackEngagement.find_by(user_id: 1, kind: 'comment')).to have_attributes(handle: 'eva', name: 'Eva')
  end

  it 'skips reads for pieces nobody else engaged with' do
    scan
    expect(client).not_to have_received(:post_reactors).with(8)
  end

  it 'reports progress and totals' do
    expect(scan).to eq(posts: 2, notes: 1, failures: 0)
    expect(progress.reload).to have_attributes(total: 3, completed: 3)
  end

  context 'with a since date' do
    let(:since) { Time.zone.parse('2026-09-15') }

    it 'stops paging once a whole page is older' do
      expect(scan[:posts]).to eq 1
    end
  end

  context 'when one piece fails' do
    before { allow(client).to receive(:post_comments).and_raise(Substack::Client::NotFound, 'gone') }

    it 'carries on with the rest' do
      expect(scan[:failures]).to eq 1
      expect(engagements).to include([1, 'c-50', 'reply'])
    end
  end

  context 'when the session is rejected' do
    before { allow(client).to receive(:post_comments).and_raise(Substack::Client::AuthError, 'expired') }

    it { expect { scan }.to raise_error(Substack::Client::AuthError) }
  end

  context 'without an author id' do
    before { SubstackSyncConfig.instance.update!(author_id: nil) }

    it { expect { scan }.to raise_error(Substack::Client::Error, /author id/) }
  end
end

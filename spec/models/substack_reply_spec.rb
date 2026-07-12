# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackReply do
  describe 'validations' do
    it { expect(described_class.new).to_not be_valid }

    it 'is valid with target, comment and timestamp' do
      expect(described_class.new(target_url: 'a', comment_url: 'b', replied_at: Time.current)).to be_valid
    end

    it 'rejects a duplicate comment_url' do
      described_class.create!(target_url: 'a', comment_url: 'dup', replied_at: Time.current)
      expect(described_class.new(target_url: 'b', comment_url: 'dup', replied_at: Time.current)).to_not be_valid
    end
  end

  describe '.by_author' do
    let(:now) { Time.current }

    before do
      described_class.create!(target_url: 't1', comment_url: 'https://x/p/y/comment/1', author_handle: 'alice', replied_at: now - 2.days)
      described_class.create!(target_url: 't2', comment_url: 'https://x/p/y/comment/2', author_handle: 'alice', replied_at: now)
      described_class.create!(target_url: 't3', comment_url: 'https://x/p/y/comment/3', author_handle: 'bob', replied_at: now - 1.day)
    end

    it 'groups replies by handle' do
      expect(described_class.by_author.keys).to contain_exactly('alice', 'bob')
    end

    it 'orders authors by most recent reply first' do
      expect(described_class.by_author.keys).to eq(%w[alice bob])
    end

    it "orders each author's replies newest first" do
      expect(described_class.by_author['alice'].map(&:target_url)).to eq(%w[t2 t1])
    end

    it 'buckets a missing handle under (unknown)' do
      described_class.create!(target_url: 't4', comment_url: 'https://x/p/y/comment/4', author_handle: nil, replied_at: now + 1.day)
      expect(described_class.by_author.keys.first).to eq('(unknown)')
    end

    it 'filters authors by handle when a query is given' do
      expect(described_class.by_author('ali').keys).to eq(['alice'])
    end

    it 'filters authors by name when a query is given' do
      described_class.create!(target_url: 't5', comment_url: 'https://x/p/y/comment/5', author_handle: 'carol', author_name: 'Carol Danvers', replied_at: now)
      expect(described_class.by_author('danvers').keys).to eq(['carol'])
    end
  end

  describe '.by_author (cross-author threads)' do
    it 'stitches a cross-author thread under the account of its root reply' do
      now = Time.current
      described_class.create!(target_url: 't', comment_url: 'https://x/p/y/comment/100', author_handle: 'alice', ancestor_path: '', replied_at: now - 1.day)
      described_class.create!(target_url: 't', comment_url: 'https://x/p/y/comment/300', author_handle: 'bob', ancestor_path: '100.200', replied_at: now)

      cards = described_class.by_author
      expect(cards.keys).to eq(['alice'])
      expect(cards['alice'].size).to eq 2
    end
  end

  describe '#reply_comment_id' do
    it 'reads a post-comment id' do
      expect(described_class.new(comment_url: 'https://x/p/y/comment/555').reply_comment_id).to eq '555'
    end

    it 'reads a note comment id' do
      expect(described_class.new(comment_url: 'https://substack.com/profile/1-x/note/c-777').reply_comment_id).to eq '777'
    end
  end

  describe '.threaded' do
    def reply(cid, ancestor, at)
      described_class.create!(target_url: 't', comment_url: "https://x/p/y/comment/#{cid}",
                              ancestor_path: ancestor, replied_at: at)
    end

    it 'nests a reply under its ancestor reply and keeps unrelated replies at root' do
      now   = Time.current
      root  = reply('100', '', now - 2.days)
      child = reply('300', '100.200', now - 1.day)
      other = reply('400', '', now)

      threaded = described_class.threaded([root, child, other])
      expect(threaded.map { |r, depth| [r.reply_comment_id, depth] }).to eq([['400', 0], ['100', 0], ['300', 1]])
    end
  end
end

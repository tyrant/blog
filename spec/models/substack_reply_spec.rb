# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackReply do
  describe 'validations' do
    it { expect(described_class.new).to_not be_valid }

    it 'is valid with target, comment and timestamp' do
      expect(described_class.new(target_url: 'a', comment_url: 'b', replied_at: Time.current)).to be_valid
    end
  end

  describe '.by_author' do
    let(:now) { Time.current }

    before do
      described_class.create!(target_url: 't1', comment_url: 'c1', author_handle: 'alice', replied_at: now - 2.days)
      described_class.create!(target_url: 't2', comment_url: 'c2', author_handle: 'alice', replied_at: now)
      described_class.create!(target_url: 't3', comment_url: 'c3', author_handle: 'bob', replied_at: now - 1.day)
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
      described_class.create!(target_url: 't4', comment_url: 'c4', author_handle: nil, replied_at: now + 1.day)
      expect(described_class.by_author.keys.first).to eq('(unknown)')
    end

    it 'filters authors by handle when a query is given' do
      expect(described_class.by_author('ali').keys).to eq(['alice'])
    end

    it 'filters authors by name when a query is given' do
      described_class.create!(target_url: 't5', comment_url: 'c5', author_handle: 'carol', author_name: 'Carol Danvers', replied_at: now)
      expect(described_class.by_author('danvers').keys).to eq(['carol'])
    end
  end
end

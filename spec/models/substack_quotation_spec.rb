# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackQuotation do
  describe 'validations' do
    it { expect(described_class.new).to_not be_valid }
    it { expect(described_class.new(quotation: 'q', comment_url: 'u')).to be_valid }
    it { expect(described_class.new(quotation: 'q')).to_not be_valid }
    it { expect(described_class.new(comment_url: 'u')).to_not be_valid }
  end

  describe 'position' do
    def quote = described_class.create!(quotation: 'q', comment_url: "https://x/comment/#{SecureRandom.hex(4)}")

    it 'appends new records to the end' do
      a = quote
      b = quote
      expect(b.position).to eq a.position + 1
    end

    it '.by_position orders by the stored position' do
      a = quote
      b = quote
      a.update!(position: 5)
      b.update!(position: 2)
      expect(described_class.by_position.to_a).to eq [b, a]
    end
  end

  describe '.reorder!' do
    let!(:records) { Array.new(3) { |i| described_class.create!(quotation: "q#{i}", comment_url: "https://x/comment/#{i}") } }

    it 'assigns positions matching the given id order' do
      described_class.reorder!([records[2].id, records[0].id, records[1].id])
      expect(described_class.by_position.to_a).to eq [records[2], records[0], records[1]]
    end

    it 'positions the ids contiguously from 0' do
      described_class.reorder!([records[2].id, records[0].id, records[1].id])
      expect([records[2], records[0], records[1]].map { |r| r.reload.position }).to eq [0, 1, 2]
    end
  end

  describe '.sample_excluding' do
    def quote(text, post_url, author: 'https://substack.com/@a')
      described_class.create!(quotation: text, comment_url: "https://x/comment/#{text.parameterize}",
                              post_title: 'P', post_url: post_url, author_name: 'A', author_url: author)
    end

    it 'excludes quotations on the given post' do
      quote('alpha', 'https://x/p/self')
      quote('beta', 'https://x/p/other')
      expect(described_class.sample_excluding('https://x/p/self', 10).map(&:post_url)).to eq(['https://x/p/other'])
    end

    it 'dedupes by quote text, so the same one never appears twice' do
      quote('same', 'https://x/p/1')
      quote('same', 'https://x/p/2')
      quote('different', 'https://x/p/3')
      texts = described_class.sample_excluding(nil, 10).map(&:quotation)
      expect(texts.count { |t| t == 'same' }).to eq 1
    end

    it 'skips quotations missing a post or author url' do
      quote('ok', 'https://x/p/1')
      described_class.create!(quotation: 'nourl', comment_url: 'https://x/comment/nourl', post_url: nil, author_url: nil)
      expect(described_class.sample_excluding(nil, 10).map(&:quotation)).to eq(['ok'])
    end

    it 'returns at most count' do
      3.times { |i| quote("q#{i}", "https://x/p/#{i}") }
      expect(described_class.sample_excluding(nil, 2).size).to eq 2
    end
  end

  describe '#populate_from_substack!' do
    subject(:quotation) { described_class.new(quotation: 'blurb', comment_url: 'https://x/comment/5') }

    let(:client) { instance_double(Substack::Client) }

    before do
      allow(client).to receive(:get_note).with('5').and_return('item' => {
        'comment' => { 'name' => 'Bob', 'handle' => 'bob' },
        'post' => { 'title' => 'A Post', 'canonical_url' => 'https://x/p/a',
                    'cover_image' => 'https://cdn/cover.jpg', 'id' => 77 }
      })
    end

    it 'fills post and author fields from the comment' do
      quotation.populate_from_substack!(client: client)
      expect(quotation).to have_attributes(
        post_url: 'https://x/p/a', post_title: 'A Post', post_image_url: 'https://cdn/cover.jpg', post_id: 77,
        author_name: 'Bob', author_url: 'https://substack.com/@bob'
      )
    end
  end
end

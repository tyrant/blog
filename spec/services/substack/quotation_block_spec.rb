# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::QuotationBlock do
  def quote(attrs = {})
    SubstackQuotation.new({ quotation: 'a blurb', post_title: 'Ch 1',
                            post_url: 'https://pub.substack.com/p/ch-1',
                            author_name: 'Eva', author_url: 'https://substack.com/@eva' }.merge(attrs))
  end

  describe '.build' do
    subject(:blocks) { described_class.build(quote) }

    it { expect(blocks.size).to eq 3 }

    it 'heads with the post title linked to the post' do
      expect(blocks[0]['type']).to eq 'heading'
      expect(blocks[0]['content'][0]['text']).to eq 'Ch 1'
      expect(blocks[0]['content'][0].dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1'
    end

    it 'italicises the quote inside a blockquote' do
      node = blocks[1]['content'][0]['content'][0]
      expect(blocks[1]['type']).to eq 'blockquote'
      expect(node['text']).to eq '“a blurb”'
      expect(node['marks'].map { |m| m['type'] }).to include 'em'
    end

    it 'right-aligns the linked author' do
      expect(blocks[2]['attrs']['textAlign']).to eq 'right'
      expect(blocks[2]['content'][0]['text']).to eq 'Eva'
      expect(blocks[2]['content'][0].dig('marks', 0, 'attrs', 'href')).to eq 'https://substack.com/@eva'
    end
  end

  describe '.triplet_at?' do
    let(:content) { [{ 'type' => 'paragraph' }] + described_class.build(quote) }

    it { expect(described_class.triplet_at?(content, 1)).to be true }
    it { expect(described_class.triplet_at?(content, 0)).to be false }
  end

  describe '.rotate' do
    let(:content) do
      [{ 'type' => 'paragraph', 'content' => [] }] +
        described_class.build(quote(quotation: 'first')) +
        described_class.build(quote(quotation: 'second')) +
        [{ 'type' => 'horizontal_rule' }]
    end
    let(:fresh) { [quote(quotation: 'fresh A'), quote(quotation: 'fresh B'), quote(quotation: 'fresh C')] }

    it 'swaps the run of triplets for the same count of fresh ones' do
      result = described_class.rotate(content, fresh)
      quotes = result.select { |b| b['type'] == 'blockquote' }.map { |b| b['content'][0]['content'][0]['text'] }
      expect(quotes).to eq ['“fresh A”', '“fresh B”']
    end

    it 'preserves the surrounding blocks' do
      result = described_class.rotate(content, fresh)
      expect([result.first['type'], result.last['type']]).to eq %w[paragraph horizontal_rule]
    end

    it 'leaves content with no quotation run untouched' do
      plain = [{ 'type' => 'paragraph' }]
      expect(described_class.rotate(plain, fresh)).to eq plain
    end
  end
end

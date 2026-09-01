# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::QuotationBlock do
  def quote(attrs = {})
    SubstackQuotation.new({ quotation: 'a blurb', post_title: 'Ch 1',
                            post_url: 'https://pub.substack.com/p/ch-1',
                            comment_url: 'https://pub.substack.com/p/ch-1/comment/42',
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

    it 'includes a 🔗 linking the original comment inside the quote line' do
      link = blocks[1]['content'][0]['content'].find { |n| n['text'] == '🔗' }
      expect(link.dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1/comment/42'
    end

    it 'omits the comment link when there is no comment_url' do
      nodes = described_class.build(quote(comment_url: nil))[1]['content'][0]['content']
      expect(nodes.none? { |n| n['text'] == '🔗' }).to be true
    end

    it 'trails the quote line with an em-dash and the linked author' do
      nodes = blocks[1]['content'][0]['content']
      expect(nodes[-2]['text']).to eq ' — '
      expect(nodes.last['text']).to eq 'Eva'
      expect(nodes.last.dig('marks', 0, 'attrs', 'href')).to eq 'https://substack.com/@eva'
    end

    it 'renders the author as plain text when there is no author_url' do
      nodes = described_class.build(quote(author_url: nil))[1]['content'][0]['content']
      expect(nodes.last).to eq('type' => 'text', 'text' => 'Eva')
    end

    it 'closes the unit with a centred "." spacer' do
      expect(blocks[2]['attrs']['textAlign']).to eq 'center'
      expect(blocks[2]['content'][0]['text']).to eq '.'
    end
  end

  describe '.unit' do
    it 'is the heading/blockquote/spacer triplet when the quotation has no embed snapshot' do
      expect(described_class.unit(quote).map { |b| b['type'] }).to eq %w[heading blockquote paragraph]
    end

    it 'is a spacer/card/blockquote triplet when the quotation has a snapshot' do
      unit = described_class.unit(quote(post_embed: { 'size' => 'sm', 'id' => 7 }))
      expect(unit.map { |b| b['type'] }).to eq %w[heading digestPostEmbed blockquote]
    end

    it "puts the quote (marked em) and attribution inside the card unit's blockquote, both visible" do
      unit = described_class.unit(quote(quotation: 'card quote', post_embed: { 'size' => 'sm' }))
      quote_node = unit[2]['content'][0]['content'][0]
      attribution_nodes = unit[2]['content'][1]['content']
      expect(quote_node['text']).to eq '“card quote”'
      expect(quote_node['marks'].map { |m| m['type'] }).to include 'em'
      expect(attribution_nodes.map { |n| n['text'] }).to eq ['🔗', ' — ', 'Eva']
    end
  end

  describe '.card' do
    it { expect(described_class.card(quote)).to be_nil }

    it 'gives each card a unique nodeId' do
      quotation = quote(post_embed: { 'size' => 'sm' })
      expect(described_class.card(quotation)['attrs']['nodeId']).to_not eq described_class.card(quotation)['attrs']['nodeId']
    end

    it 'forces the "md" size regardless of the stored snapshot size' do
      lead = described_class.card(quote(post_embed: { 'size' => 'sm', 'id' => 7 }))
      expect(lead['attrs']).to include('size' => 'md', 'id' => 7)
    end

    it 'captions the card with the quote text' do
      lead = described_class.card(quote(quotation: 'card quote', post_embed: { 'size' => 'sm' }))
      expect(lead['attrs']['caption']).to eq '“card quote”'
    end
  end

  describe '.quote_blockquote' do
    subject(:attribution_nodes) { described_class.quote_blockquote(quote)['content'][1]['content'] }

    it 'links a 🔗 to the comment, then an em-dash and the linked author, unmarked' do
      expect(attribution_nodes.map { |n| n['text'] }).to eq ['🔗', ' — ', 'Eva']
      expect(attribution_nodes[0].dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1/comment/42'
      expect(attribution_nodes[2].dig('marks', 0, 'attrs', 'href')).to eq 'https://substack.com/@eva'
      expect(attribution_nodes.flat_map { |n| Array(n['marks']).map { |m| m['type'] } }).to_not include 'em'
    end

    it 'omits the comment link when there is no comment_url' do
      nodes = described_class.quote_blockquote(quote(comment_url: nil))['content'][1]['content']
      expect(nodes.map { |n| n['text'] }).to eq [' — ', 'Eva']
    end

    it 'renders the author as plain text when there is no author_url' do
      nodes = described_class.quote_blockquote(quote(author_url: nil))['content'][1]['content']
      expect(nodes.last).to eq('type' => 'text', 'text' => 'Eva')
    end
  end

  describe '.triplet_at?' do
    let(:content) { [{ 'type' => 'paragraph' }] + described_class.build(quote) }

    it { expect(described_class.triplet_at?(content, 1)).to be true }
    it { expect(described_class.triplet_at?(content, 0)).to be false }

    it 'matches a card-led unit whose third block is a bare paragraph' do
      card = described_class.card(quote(post_embed: { 'size' => 'sm' }))
      unit = [card, described_class.build(quote)[1], { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => '.' }] }]
      expect(described_class.triplet_at?(unit, 0)).to be true
    end

    it 'matches a spacer/card/blockquote triplet (the current card shape)' do
      unit = described_class.unit(quote(post_embed: { 'size' => 'sm' }))
      expect(described_class.triplet_at?(unit, 0)).to be true
    end
  end

  describe '.walk_units' do
    it 'counts a run of card-shape units and returns the index past it' do
      content = [{ 'type' => 'paragraph' }] +
        described_class.unit(quote(post_embed: { 'size' => 'sm' })) +
        described_class.unit(quote(post_embed: { 'size' => 'sm' })) +
        [{ 'type' => 'horizontal_rule' }]
      expect(described_class.walk_units(content, 1)).to eq [2, 7]
    end

    it 'counts a mixed run of legacy and card-shape units' do
      content = described_class.build(quote) + described_class.unit(quote(post_embed: { 'size' => 'sm' }))
      expect(described_class.walk_units(content, 0)).to eq [2, 6]
    end
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

    it 'swaps a run of card-shape units for fresh ones, preserving the shape' do
      card_content = [{ 'type' => 'paragraph' }] +
        described_class.unit(quote(quotation: 'old', post_embed: { 'size' => 'sm' }))
      fresh_with_embed = [quote(quotation: 'new', post_embed: { 'size' => 'sm' })]
      result = described_class.rotate(card_content, fresh_with_embed)
      expect(result[2]['attrs']['caption']).to eq '“new”'
      expect(result.size).to eq 4
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::QuotationBlock do
  def quote(attrs = {})
    SubstackQuotation.new({ quotation: 'a blurb', post_title: 'Ch 1',
                            post_url: 'https://pub.substack.com/p/ch-1',
                            comment_url: 'https://pub.substack.com/p/ch-1/comment/42',
                            substack_user: create(:substack_user, name: 'Eva', handle: 'eva') }.merge(attrs))
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

    it 'renders the author as plain text when there is no profile handle' do
      nodes = described_class.build(quote(substack_user: create(:substack_user, name: 'Eva', handle: nil)))[1]['content'][0]['content']
      expect(nodes.last).to eq('type' => 'text', 'text' => 'Eva')
    end

    it 'closes the unit with a centred "." spacer' do
      expect(blocks[2]['attrs']['textAlign']).to eq 'center'
      expect(blocks[2]['content'][0]['text']).to eq '.'
    end
  end

  describe '.unit' do
    let(:embed) { { 'size' => 'sm', 'id' => 7 } }
    let(:unit) { described_class.unit(quote(quotation: 'card quote', post_embed: embed)) }

    before do
      SubstackSyncConfig.instance.update!(publication_host: 'pub.substack.com', reviews_page_size: 20,
                                          subtitle_variables_json: '{"compliment": ["gnarly", "cracking"], "quantity": ["bags"]}')
    end

    it 'is card, quote, signature line, then a centred h5 "." spacer' do
      expect(unit.map { |b| b['type'] }).to eq %w[digestPostEmbed blockquote paragraph heading]
      expect(unit[3]).to eq described_class.trailing_spacer
    end

    it 'leads with the post-title heading when there is no embed snapshot' do
      expect(described_class.unit(quote).first).to eq described_class.heading(quote)
    end

    it 'drops the spacer with spacer: false' do
      expect(described_class.unit(quote(post_embed: embed), spacer: false).map { |b| b['type'] })
        .to eq %w[digestPostEmbed blockquote paragraph]
    end

    it 'block-quotes only the italic quote' do
      expect(unit[1]).to eq described_class.quote_only_blockquote(quote(quotation: 'card quote'))
    end

    describe 'the signature line' do
      let(:signature) { unit[2]['content'] }

      it 'reads "🔗 — <Blizzard-style thanks to @handle>"' do
        expect(signature.map { |n| n['text'] }.join)
          .to match(/\A🔗 — Bags of thanks to the Most \w+ @eva, they're \w+, do check 'em out/)
      end

      it 'leaves the @handle unlinked, for a mention to be made by hand' do
        expect(signature.find { |n| n['text'] == '@eva' }).to eq('type' => 'text', 'text' => '@eva')
      end

      it "links the 🔗 to the review's spot on its Reviews page" do
        saved = quote.tap(&:save!)
        link = described_class.unit(saved)[2]['content'][0]
        expect(link['text']).to eq '🔗'
        expect(link.dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/reviews?open=false#%C2%A71'
      end

      it 'links the 🔗 to the comment for a quotation not on the Reviews pages' do
        expect(signature[0].dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1/comment/42'
      end
    end
  end

  describe '.review_unit' do
    before do
      allow(SubstackSyncConfig).to receive(:instance).and_return(
        instance_double(SubstackSyncConfig, subtitle_variables: { 'quantity' => ['bags'] })
      )
      allow(Substack::Blizzard::QuotationNote).to receive(:random_compliment).with(n: 2).and_return(%w[gnarly cracking])
    end

    let(:unit) { described_class.review_unit(quote(post_embed: { 'size' => 'sm' }, substack_user: create(:substack_user, name: 'Eva', handle: 'eva', pronouns: 'she/her')), number: 12) }
    let(:signature) { unit[3]['content'] }

    it { expect(unit.map { |b| b['type'] }).to eq %w[heading digestPostEmbed blockquote paragraph heading] }
    it { expect(unit[0]).to eq described_class.review_number(12) }
    it { expect(unit[4]).to eq described_class.review_spacer }

    it 'block-quotes only the italic quote' do
      expect(unit[2]['content'].size).to eq 1
      expect(unit[2]['content'][0]['content']).to eq [{ 'type' => 'text', 'text' => '“a blurb”', 'marks' => [{ 'type' => 'em' }] }]
    end

    it 'signs it "🔗 — <Blizzard-style thanks>" in post marks, with the author\'s @handle' do
      expect(signature.map { |n| n['text'] }.join)
        .to eq "🔗 — Bags of thanks to the Most Gnarly @eva, she's cracking, do check her out and/or send her some love."
      expect(signature[0].dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1/comment/42'
      expect(signature.find { |n| n['text'] == 'Most ' }['marks']).to eq [{ 'type' => 'em' }]
      expect(signature.find { |n| n['text'] == 'cracking' }['marks']).to eq [{ 'type' => 'strong' }, { 'type' => 'em' }]
    end

    it 'leaves the @handle unlinked, for a mention to be made by hand' do
      expect(signature.find { |n| n['text'] == '@eva' }).to eq('type' => 'text', 'text' => '@eva')
    end

    it 'follows the number with the post-title heading when there is no embed snapshot' do
      expect(described_class.review_unit(quote, number: 1)[1]).to eq described_class.heading(quote)
    end

    it 'omits the 🔗 when there is no comment_url' do
      nodes = described_class.review_unit(quote(comment_url: nil), number: 1)[3]['content']
      expect(nodes.first['text']).to eq ' — '
    end
  end

  describe '.review_author' do
    it { expect(described_class.review_author(quote)).to eq('type' => 'text', 'text' => '@eva') }

    it 'falls back to the plain name when there is no handle' do
      node = described_class.review_author(quote(substack_user: create(:substack_user, name: 'Eva', handle: nil)))
      expect(node).to eq('type' => 'text', 'text' => 'Eva')
    end
  end

  describe '.review_number' do
    it { expect(described_class.review_number(7)).to eq('type' => 'heading', 'attrs' => { 'textAlign' => nil, 'level' => 4 },
                                                         'content' => [{ 'type' => 'text', 'text' => '#7' }]) }
  end

  describe '.review_spacer' do
    it { expect(described_class.review_spacer).to eq('type' => 'heading', 'attrs' => { 'textAlign' => 'left', 'level' => 6 }) }
  end

  describe '.card' do
    it { expect(described_class.card(quote)).to be_nil }

    it 'gives each card a unique nodeId' do
      quotation = quote(post_embed: { 'size' => 'sm' })
      expect(described_class.card(quotation)['attrs']['nodeId']).to_not eq described_class.card(quotation)['attrs']['nodeId']
    end

    it 'forces the "sm" size regardless of the stored snapshot size' do
      lead = described_class.card(quote(post_embed: { 'size' => 'md', 'id' => 7 }))
      expect(lead['attrs']).to include('size' => 'sm', 'id' => 7)
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

    it 'renders the author as plain text when there is no profile handle' do
      nodes = described_class.quote_blockquote(quote(substack_user: create(:substack_user, name: 'Eva', handle: nil)))['content'][1]['content']
      expect(nodes.last).to eq('type' => 'text', 'text' => 'Eva')
    end
  end

  describe '.callout' do
    subject(:callout) { described_class.callout(quote) }

    before { SubstackSyncConfig.instance.update!(publication_host: 'pub.substack.com', reviews_page_size: 20) }

    let(:nodes) { callout['content'][0]['content'] }

    it 'is a Callout Block holding one paragraph' do
      expect(callout['type']).to eq 'calloutBlock'
      expect(callout['content'].map { |b| b['type'] }).to eq %w[paragraph]
    end

    it 'carries the italic quote, 🔗 and @handle on that one line' do
      expect(nodes.map { |n| n['text'] }).to eq ['“a blurb”', ' ', '🔗', ' — ', '@eva']
      expect(nodes[0]['marks'].map { |m| m['type'] }).to include 'em'
    end

    it 'leaves the @handle unlinked, for a mention to be made by hand' do
      expect(nodes.last).to eq('type' => 'text', 'text' => '@eva')
    end

    it "links the 🔗 to the review's spot on its Reviews page" do
      saved = quote.tap(&:save!)
      link = described_class.callout(saved)['content'][0]['content'][2]
      expect(link.dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/reviews?open=false#%C2%A71'
    end

    it 'links the 🔗 to the comment for a quotation not on the Reviews pages' do
      expect(nodes[2].dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1/comment/42'
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

    it 'matches the current footer unit, with or without its spacer' do
      [true, false].each do |spacer|
        expect(described_class.triplet_at?(described_class.unit(quote(post_embed: { 'size' => 'sm' }), spacer: spacer), 0)).to be true
      end
    end

    it 'matches an earlier card/attributed-blockquote/spacer unit' do
      unit = [described_class.card(quote(post_embed: { 'size' => 'sm' })), described_class.quote_blockquote(quote), described_class.trailing_spacer]
      expect(described_class.triplet_at?(unit, 0)).to be true
    end

  end

  describe '.walk_units' do
    it 'counts a run of card-shape units and returns the index past it' do
      content = [{ 'type' => 'paragraph' }] +
        described_class.unit(quote(post_embed: { 'size' => 'sm' })) +
        described_class.unit(quote(post_embed: { 'size' => 'sm' })) +
        [{ 'type' => 'horizontal_rule' }]
      expect(described_class.walk_units(content, 1)).to eq [2, 9]
    end

    it 'counts spacer-less card units (the current layout) up to the next block' do
      content = described_class.unit(quote(post_embed: { 'size' => 'sm' }), spacer: false) +
        described_class.unit(quote(post_embed: { 'size' => 'sm' }), spacer: false) +
        [{ 'type' => 'button' }]
      expect(described_class.walk_units(content, 0)).to eq [2, 6]
    end

    it 'counts a run of earlier card/attributed-blockquote units' do
      earlier = [described_class.card(quote(post_embed: { 'size' => 'sm' })), described_class.quote_blockquote(quote)]
      content = earlier + earlier + [{ 'type' => 'button' }]
      expect(described_class.walk_units(content, 0)).to eq [2, 4]
    end

    it 'does not swallow a following paragraph as a spacer-less unit’s spacer' do
      content = described_class.unit(quote(post_embed: { 'size' => 'sm' }), spacer: false) +
        [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Enjoy oodles more kudos' }] }]
      expect(described_class.walk_units(content, 0)).to eq [1, 3]
    end

    it 'counts a mixed run of legacy and card-shape units' do
      content = described_class.build(quote) + described_class.unit(quote(post_embed: { 'size' => 'sm' }))
      expect(described_class.walk_units(content, 0)).to eq [2, 7]
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
      expect(result[1]['attrs']['caption']).to eq '“new”'
      expect(result.size).to eq 5
    end

    it 'upgrades an earlier spacer-less card run to the current shape, still spacer-less' do
      earlier = [{ 'type' => 'paragraph' }, described_class.card(quote(post_embed: { 'size' => 'sm' })),
                 described_class.quote_blockquote(quote), { 'type' => 'button' }]
      result = described_class.rotate(earlier, [quote(quotation: 'new', post_embed: { 'size' => 'sm' })])
      expect(result.map { |b| b['type'] }).to eq %w[paragraph digestPostEmbed blockquote paragraph button]
    end

    it 'keeps a spacer-less run spacer-less' do
      card_content = [{ 'type' => 'paragraph' }] +
        described_class.unit(quote(quotation: 'old', post_embed: { 'size' => 'sm' }), spacer: false) +
        [{ 'type' => 'button' }]
      fresh_with_embed = [quote(quotation: 'new', post_embed: { 'size' => 'sm' })]
      result = described_class.rotate(card_content, fresh_with_embed)
      expect(result.map { |b| b['type'] }).to eq %w[paragraph digestPostEmbed blockquote paragraph button]
      expect(result[1]['attrs']['caption']).to eq '“new”'
    end
  end
end

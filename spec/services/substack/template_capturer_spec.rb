# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TemplateCapturer do
  subject(:capture) { described_class.execute(draft_id: 42, client: client) }

  let(:client) { instance_double(Substack::Client) }

  def triplet
    Substack::QuotationBlock.build(SubstackQuotation.new(quotation: 'x', post_title: 'P', post_url: 'https://pub/p/x',
                                                         substack_user: create(:substack_user, name: 'A', handle: 'a')))
  end

  let(:blocks) do
    [
      { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'the body' }] },
      { 'type' => 'heading', 'attrs' => { 'level' => 5 }, 'content' => [{ 'type' => 'text', 'text' => 'Original: https://x' }] },
      { 'type' => 'button' }
    ] + triplet + triplet + [
      { 'type' => 'heading', 'content' => [{ 'type' => 'text', 'text' => 'Bullshit Emeritus: YOUR TURN' }] },
      { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'comment your own' }] },
      { 'type' => 'subscribeWidget' }
    ]
  end

  before do
    allow(client).to receive(:get_draft).with(42)
      .and_return('draft_subtitle' => 'The subtitle', 'draft_body' => { 'content' => blocks }.to_json)
  end

  def footer = SubstackSyncConfig.instance.footer_json

  it 'leaves the existing subtitle untouched' do
    SubstackSyncConfig.instance.update!(subtitle: 'Keep me')
    capture
    expect(SubstackSyncConfig.instance.subtitle).to eq 'Keep me'
  end

  it 'captures from the Original link onward, dropping the body' do
    capture
    expect(footer.first['type']).to eq 'syncOriginalLink'
  end

  it 'replaces the quotation run with one syncQuotations directive' do
    capture
    directive = footer.find { |b| b['type'] == 'syncQuotations' }
    expect(directive['attrs']['count']).to eq 2
    expect(footer.count { |b| b['type'] == 'blockquote' }).to eq 0
  end

  context 'when the quotation units are post-embed cards' do
    def card_unit
      [{ 'type' => 'digestPostEmbed', 'attrs' => { 'canonical_url' => 'https://pub/p/x', 'size' => 'sm' } },
       { 'type' => 'blockquote', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'q', 'marks' => [{ 'type' => 'em' }] }] }] },
       { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => '.' }] }]
    end

    let(:blocks) do
      [{ 'type' => 'heading', 'attrs' => { 'level' => 5 }, 'content' => [{ 'type' => 'text', 'text' => 'Original: https://x' }] }] +
        card_unit + card_unit + [{ 'type' => 'subscribeWidget' }]
    end

    it 'still collapses the card run into one syncQuotations directive' do
      capture
      directive = footer.find { |b| b['type'] == 'syncQuotations' }
      expect(directive['attrs']['count']).to eq 2
      expect(footer.none? { |b| b['type'] == 'digestPostEmbed' }).to be true
    end
  end

  context 'when the quotation units are the current spacer + card + blockquote triplets' do
    def new_unit
      Substack::QuotationBlock.unit(SubstackQuotation.new(quotation: 'x', post_title: 'P', post_url: 'https://pub/p/x',
                                                           comment_url: 'https://pub/p/x/comment/1',
                                                           substack_user: create(:substack_user, name: 'A', handle: 'a'),
                                                           post_embed: { 'canonical_url' => 'https://pub/p/x', 'size' => 'sm' }))
    end

    let(:blocks) do
      [{ 'type' => 'heading', 'attrs' => { 'level' => 5 }, 'content' => [{ 'type' => 'text', 'text' => 'Original: https://x' }] }] +
        new_unit + new_unit + [{ 'type' => 'subscribeWidget' }]
    end

    it 'collapses the run into one syncQuotations directive' do
      capture
      directive = footer.find { |b| b['type'] == 'syncQuotations' }
      expect(directive['attrs']['count']).to eq 2
      expect(footer.none? { |b| b['type'] == 'digestPostEmbed' }).to be true
    end
  end

  it 'no longer gates the Bullshit Emeritus section on a tag' do
    capture
    expect(footer.none? { |b| b['type'] == 'syncIf' }).to be true
  end

  context 'with a configured tag conditional' do
    before { stub_const("#{described_class}::CONDITIONALS", [{ heading: 'Bullshit Emeritus', tag: 'Shite Advice' }]) }

    it 'wraps the section in a tag conditional' do
      capture
      conditional = footer.find { |b| b['type'] == 'syncIf' }
      expect(conditional['attrs']['tag']).to eq 'Shite Advice'
      expect(conditional['content'].map { |b| b['type'] }).to eq %w[heading paragraph]
    end

    it 'leaves the trailing subscribe widget outside the conditional' do
      capture
      expect(footer.last['type']).to eq 'subscribeWidget'
    end
  end

  context 'when the draft has the platform-links section instead of an Original link' do
    def centred_heading(text, level)
      { 'type' => 'heading', 'attrs' => { 'textAlign' => 'center', 'level' => level }, 'content' => [{ 'type' => 'text', 'text' => text }] }
    end

    def link(text)
      { 'type' => 'text', 'text' => text, 'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => "https://#{text}" } }] }
    end

    let(:links_row) do
      { 'type' => 'heading', 'attrs' => { 'textAlign' => 'center', 'level' => 4 },
        'content' => [link('My website'), { 'type' => 'text', 'text' => ' · ' }, link('Facebook')] }
    end

    let(:blocks) do
      [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'the body' }] },
       centred_heading('.', 6), centred_heading('This post ALSO moonwalks resplendent twixt', 5), links_row,
       { 'type' => 'button' }] + triplet + triplet + [{ 'type' => 'subscribeWidget' }]
    end

    it 'captures from the lead-in headings above the links row' do
      capture
      expect(footer.first(2).map { |b| b['content'].first['text'] }).to eq ['.', 'This post ALSO moonwalks resplendent twixt']
    end

    it 'replaces the links row with a syncPlatformLinks directive keeping its heading attrs' do
      capture
      expect(footer[2]).to eq('type' => 'syncPlatformLinks', 'attrs' => { 'textAlign' => 'center', 'level' => 4 })
    end

    it 'emits no syncOriginalLink' do
      capture
      expect(footer.none? { |b| b['type'] == 'syncOriginalLink' }).to be true
    end

    it 'still collapses the quotation run into a randomised syncQuotations directive' do
      capture
      expect(footer.find { |b| b['type'] == 'syncQuotations' }['attrs']['count']).to eq 2
    end
  end

  context 'with the current layout: footer from the divider above THANK YOU, links section last' do
    def text_block(type, text, attrs = nil)
      block = { 'type' => type, 'content' => [{ 'type' => 'text', 'text' => text }] }
      attrs ? block.merge('attrs' => attrs) : block
    end

    def link(text)
      { 'type' => 'text', 'text' => text, 'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => "https://#{text}" } }] }
    end

    let(:divider) { { 'type' => 'horizontal_rule' } }
    let(:links_row) do
      { 'type' => 'heading', 'attrs' => { 'textAlign' => 'center', 'level' => 4 },
        'content' => [link('My website'), { 'type' => 'text', 'text' => ' · ' }, link('Facebook')] }
    end

    # As in the real reference draft: one review card + attributed blockquote,
    # no "." spacer, straight into the "Become a Cool Cat" button.
    def bare_card_unit
      Substack::QuotationBlock.unit(
        SubstackQuotation.new(quotation: 'x', post_title: 'P', post_url: 'https://pub/p/x', comment_url: 'https://pub/p/x/comment/1',
                              substack_user: create(:substack_user, name: 'A', handle: 'a'),
                              post_embed: { 'canonical_url' => 'https://pub/p/x', 'size' => 'sm' }),
        spacer: false
      )
    end

    # Bullshit Emeritus is now one audience-specific block per subscriber type.
    let(:emeritus_blocks) do
      { %w[paid_sub founding_sub] => 'Bullshit Emeritus: hawt stuff, thanks for paying',
        %w[non_sub] => 'Bullshit Emeritus: crave more? Subscribe!',
        %w[free_sub] => 'Bullshit Emeritus: you’re hip, level up?' }.map do |audiences, text|
        { 'type' => 'dynamicContent', 'attrs' => { 'audiences' => audiences }, 'content' => [text_block('paragraph', text)] }
      end
    end

    let(:blocks) do
      [text_block('heading', 'Eva asks'), text_block('paragraph', 'the question'),
       text_block('heading', 'My answer'), text_block('paragraph', 'the answer'),
       divider, text_block('heading', '😘 THANK YOU 😘', 'textAlign' => 'center'), text_block('paragraph', 'thanks'),
       divider, text_block('heading', 'Bullshit Hors D’oeuvres: TERRIBLE ADVICE'), text_block('paragraph', 'contain 406 gems and counting')] +
        bare_card_unit +
        [{ 'type' => 'button' },
         divider, text_block('heading', 'Bullshit Banquet: the SEXYVERSE NOVELS'), text_block('paragraph', 'Raw Phwoar'),
         divider] + emeritus_blocks +
        [{ 'type' => 'subscribeWidget' },
         text_block('heading', '.', 'textAlign' => 'center', 'level' => 6),
         text_block('heading', 'This post also moonwalks resplendent twixt', 'textAlign' => 'center', 'level' => 5),
         links_row]
    end

    it 'starts the footer at the divider above THANK YOU, dropping the question and answer' do
      capture
      expect(footer.first).to eq('type' => 'horizontal_rule')
      expect(footer[1]['content'].first['text']).to eq '😘 THANK YOU 😘'
      expect(footer.to_json).not_to include('My answer', 'Eva asks')
    end

    it 'ends with the moonwalks lead-in and a syncPlatformLinks directive' do
      capture
      expect(footer.last).to eq('type' => 'syncPlatformLinks', 'attrs' => { 'textAlign' => 'center', 'level' => 4 })
      expect(footer[-2]['content'].first['text']).to eq 'This post also moonwalks resplendent twixt'
    end

    it 'emits no syncOriginalLink' do
      capture
      expect(footer.none? { |b| b['type'] == 'syncOriginalLink' }).to be true
    end

    it 'collapses the spacer-less Hors D’oeuvres review into a spacer-less syncQuotations directive' do
      capture
      directive = footer.find { |b| b['type'] == 'syncQuotations' }
      expect(directive['attrs']).to eq('count' => 1, 'spacer' => false)
      expect(footer.none? { |b| b['type'] == 'digestPostEmbed' }).to be true
      expect(footer[footer.index(directive) + 1]['type']).to eq 'button'
    end

    it 'keeps the audience-specific Bullshit Emeritus blocks as-is, on every post' do
      capture
      expect(footer.none? { |b| b['type'] == 'syncIf' }).to be true
      expect(footer.select { |b| b['type'] == 'dynamicContent' }).to eq emeritus_blocks
    end
  end

  context 'when the draft has none of the markers' do
    let(:blocks) { [{ 'type' => 'paragraph' }] }

    it { expect { capture }.to raise_error(/THANK YOU/) }
  end
end

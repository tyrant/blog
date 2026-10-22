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

  it 'wraps the Bullshit Emeritus section in a tag conditional' do
    capture
    conditional = footer.find { |b| b['type'] == 'syncIf' }
    expect(conditional['attrs']['tag']).to eq 'Shite Advice'
    expect(conditional['content'].map { |b| b['type'] }).to eq %w[heading paragraph]
  end

  it 'leaves the trailing subscribe widget outside the conditional' do
    capture
    expect(footer.last['type']).to eq 'subscribeWidget'
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

  context 'when the draft has neither a links row nor an Original link' do
    let(:blocks) { [{ 'type' => 'paragraph' }] }

    it { expect { capture }.to raise_error(/Original/) }
  end
end

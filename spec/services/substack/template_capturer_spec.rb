# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TemplateCapturer do
  subject(:capture) { described_class.execute(draft_id: 42, client: client) }

  let(:client) { instance_double(Substack::Client) }

  def triplet
    Substack::QuotationBlock.build(SubstackQuotation.new(quotation: 'x', post_title: 'P', post_url: 'https://pub/p/x',
                                                         author_name: 'A', author_url: 'https://substack.com/@a'))
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

  context 'when the draft has no Original link' do
    let(:blocks) { [{ 'type' => 'paragraph' }] }

    it { expect { capture }.to raise_error(/Original/) }
  end
end

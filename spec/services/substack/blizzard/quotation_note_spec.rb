# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::QuotationNote do
  def quote(attrs = {})
    SubstackQuotation.new({ quotation: 'a blurb', post_title: 'Ch 1',
                            post_url: 'https://pub.substack.com/p/ch-1',
                            comment_url: 'https://pub.substack.com/p/ch-1/comment/42',
                            substack_user: create(:substack_user, name: 'Eva', handle: 'eva', user_id: 69847396) }.merge(attrs))
  end

  before do
    allow(SubstackSyncConfig).to receive(:instance)
      .and_return(instance_double(SubstackSyncConfig,
                                   subtitle_variables: { 'compliment' => ['cracking'], 'quantity' => ['bags'] }))
  end

  describe '.build' do
    subject(:doc) { described_class.build(quote) }

    it { expect(doc['type']).to eq 'doc' }
    it { expect(doc['attrs']).to eq('schemaVersion' => 'v1') }
    it { expect(doc['content'][0]).to eq described_class.title(quote) }
    it { expect(doc['content'][1]).to eq described_class.quote(quote) }
    it { expect(doc['content'][2]).to eq described_class.source(quote) }
    it { expect(doc['content'][3]).to eq described_class.attribution(quote) }
    it { expect(doc['content'][4]['type']).to eq 'paragraph' }
  end

  describe '.title' do
    subject(:node) { described_class.title(quote) }

    it { expect(node['type']).to eq 'paragraph' }
    it { expect(node['content'][0]).to eq('type' => 'text', 'text' => 'Sexyverse Advice: another ', 'marks' => [{ 'type' => 'bold' }]) }
    it { expect(node['content'][1]).to eq('type' => 'text', 'text' => 'CRACKING', 'marks' => [{ 'type' => 'bold' }, { 'type' => 'italic' }]) }
    it { expect(node['content'][2]).to eq('type' => 'text', 'text' => ' review', 'marks' => [{ 'type' => 'bold' }]) }

    describe 'when no compliment is configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      it { expect(node['content'][1]['text']).to eq '' }
    end
  end

  describe '.quote' do
    subject(:node) { described_class.quote(quote) }

    it { expect(node['type']).to eq 'blockquote' }
    it { expect(node['content'][0]['type']).to eq 'paragraph' }
    it { expect(node['content'][0]['content'][0]).to eq('type' => 'text', 'text' => '"a blurb"', 'marks' => [{ 'type' => 'italic' }]) }
  end

  describe '.source' do
    subject(:node) { described_class.source(quote) }

    it { expect(node['type']).to eq 'paragraph' }
    it { expect(node['content'][0]).to eq('type' => 'text', 'text' => '🔗 — ') }
    it { expect(node['content'][1]).to eq('type' => 'text', 'text' => 'blargh-placeholder-text',
                                            'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => 'https://pub.substack.com/p/ch-1/comment/42' } }]) }
    it { expect(node['content'][2]).to eq('type' => 'text', 'text' => '.') }
  end

  describe '.attribution' do
    subject(:node) { described_class.attribution(quote) }

    before { allow(described_class).to receive(:random_compliment).with(n: 2).and_return(%w[spiffy cracking]) }

    it { expect(node['type']).to eq 'paragraph' }
    it { expect(node['content']).to eq described_class.attribution_nodes(quote) }
  end

  describe '.attribution_nodes' do
    subject(:nodes) { described_class.attribution_nodes(quote) }

    before { allow(described_class).to receive(:random_compliment).with(n: 2).and_return(%w[spiffy cracking]) }

    it { expect(nodes[0]).to eq('type' => 'text', 'text' => 'Bags of thanks to the ') }
    it { expect(nodes[1]).to eq('type' => 'text', 'text' => 'Most ', 'marks' => [{ 'type' => 'italic' }]) }
    it { expect(nodes[2]).to eq('type' => 'text', 'text' => 'Spiffy ') }
    it { expect(nodes[3]).to eq('type' => 'substack_mention',
                                 'attrs' => { 'id' => 69847396, 'label' => 'eva', 'mentionType' => 'user', 'url' => nil }) }
    it { expect(nodes[4]).to eq('type' => 'text', 'text' => ", they're ") }
    it { expect(nodes[5]).to eq('type' => 'text', 'text' => 'cracking', 'marks' => [{ 'type' => 'bold' }, { 'type' => 'italic' }]) }
    it { expect(nodes[6]).to eq('type' => 'text', 'text' => ", do check 'em out and/or send them some love.") }

    it 'is a flat list of nodes (a nested array makes Substack reject the whole Note)' do
      expect(nodes).to all(be_a(Hash))
    end

    it 'draws two distinct compliments from the configured list' do
      allow(described_class).to receive(:random_compliment).and_call_original
      allow(SubstackSyncConfig).to receive(:instance)
        .and_return(instance_double(SubstackSyncConfig, subtitle_variables: { 'compliment' => %w[spiffy cracking], 'quantity' => ['bags'] }))
      texts = nodes.map { |n| n['text'] }
      expect([[texts[2], texts[5]]]).to include(['Spiffy ', 'cracking']).or include(['Cracking ', 'spiffy'])
    end

    describe 'with the post schema\'s marks and a linked author (the Reviews pages)' do
      subject(:nodes) { described_class.attribution_nodes(quote, bold: 'strong', italic: 'em', author_node: { 'type' => 'text', 'text' => 'Eva' }) }

      it { expect(nodes[1]['marks']).to eq [{ 'type' => 'em' }] }
      it { expect(nodes[3]).to eq('type' => 'text', 'text' => 'Eva') }
      it { expect(nodes[5]['marks']).to eq [{ 'type' => 'strong' }, { 'type' => 'em' }] }
    end

    describe 'when no quantity is configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      it { expect(nodes[0]['text']).to eq ' of thanks to the ' }
    end

    describe 'when the author is she/her' do
      subject(:nodes) { described_class.attribution_nodes(quote(substack_user: create(:substack_user, name: 'Eva', pronouns: 'she/her'))) }
      it { expect(nodes[4]).to eq('type' => 'text', 'text' => ", she's ") }
      it { expect(nodes[6]).to eq('type' => 'text', 'text' => ', do check her out and/or send her some love.') }
    end

    describe 'when the author has no captured user id' do
      subject(:nodes) { described_class.attribution_nodes(quote(substack_user: create(:substack_user, name: 'Eva', handle: 'eva', user_id: nil))) }
      it { expect(nodes[3]).to eq('type' => 'text', 'text' => 'Eva',
                                   'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => 'https://substack.com/@eva' } }]) }
    end
  end

  describe '.author' do
    it { expect(described_class.author(quote)).to eq('type' => 'substack_mention',
                                                        'attrs' => { 'id' => 69847396, 'label' => 'eva', 'mentionType' => 'user', 'url' => nil }) }

    it 'uses the unique handle, not the display name shared by many accounts' do
      author = described_class.author(quote(substack_user: create(:substack_user, name: 'Patrick Mill', handle: 'audiohubstudios')))
      expect(author['attrs']['label']).to eq 'audiohubstudios'
    end

    describe 'when the author has no captured user id' do
      it { expect(described_class.author(quote(substack_user: create(:substack_user, name: 'Eva', handle: 'eva', user_id: nil)))).to eq('type' => 'text', 'text' => 'Eva',
                                                                               'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => 'https://substack.com/@eva' } }]) }
    end

    describe 'when the author has no handle' do
      it { expect(described_class.author(quote(substack_user: create(:substack_user, name: 'Eva', handle: nil)))['attrs']['label']).to eq 'Eva' }
    end
  end

  describe '.pronoun_wording' do
    def wording_for(pronouns) = described_class.pronoun_wording(quote(substack_user: create(:substack_user, pronouns: pronouns)))

    it { expect(wording_for('they/them')).to eq('they_are' => "they're", 'send_love' => "check 'em out and/or send them some love.") }
    it { expect(wording_for('she/her')).to eq('they_are' => "she's", 'send_love' => 'check her out and/or send her some love.') }
    it { expect(wording_for('He/Him')).to eq('they_are' => "he's", 'send_love' => 'check him out and/or send him some love.') }
    it { expect(wording_for('xe/xem')).to eq described_class::NEUTRAL_WORDING }
    it { expect(described_class.pronoun_wording(quote(substack_user: nil))).to eq described_class::NEUTRAL_WORDING }
  end

  describe '.more_reviews' do
    subject(:node) { described_class.more_reviews }

    let(:verbs) { ['Enjoy', 'Peruse', 'Snuffle up', 'Savour', 'Yum up', 'Chow down', 'Gnaw', 'Gobble', 'Hoick'] }

    it { expect(node['type']).to eq 'paragraph' }
    it { expect(verbs.any? { |verb| node['content'][0]['text'] == "#{verb} oodles more kudos at my " }).to be true }
    it { expect(node['content'][1]).to eq('type' => 'text', 'text' => 'Reviews Pages', 'marks' => [{ 'type' => 'bold' }, { 'type' => 'italic' }]) }
    it { expect(node['content'][2]).to eq('type' => 'text', 'text' => ': ') }
    it { expect(node['content'][3]).to eq('type' => 'text', 'text' => 'blargh-placeholder-text',
                                            'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => described_class::REVIEWS_URL } }]) }
    it { expect(node['content'][4]).to eq('type' => 'text', 'text' => '.') }
  end

  describe '.text' do
    it { expect(described_class.text('hello')).to eq('type' => 'text', 'text' => 'hello') }
    it { expect(described_class.text(nil)).to eq('type' => 'text', 'text' => '') }
    it { expect(described_class.text('hello', marks: [{ 'type' => 'bold' }])).to eq('type' => 'text', 'text' => 'hello', 'marks' => [{ 'type' => 'bold' }]) }
  end

  describe '.link' do
    it { expect(described_class.link('https://example.com')).to eq('type' => 'link', 'attrs' => { 'href' => 'https://example.com' }) }
  end

  describe '.random_compliment' do
    it { expect(described_class.random_compliment).to eq ['cracking'] }

    it 'draws n distinct compliments' do
      allow(SubstackSyncConfig).to receive(:instance)
        .and_return(instance_double(SubstackSyncConfig, subtitle_variables: { 'compliment' => %w[a b c] }))
      drawn = described_class.random_compliment(n: 2)
      expect(drawn.size).to eq 2
      expect(drawn.uniq.size).to eq 2
    end

    describe 'when none configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      it { expect(described_class.random_compliment).to eq [] }
    end
  end

  describe '.random_quantity' do
    it { expect(described_class.random_quantity).to eq 'bags' }

    describe 'when none configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      it { expect(described_class.random_quantity).to be_nil }
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::QuotationNote do
  def quote(attrs = {})
    SubstackQuotation.new({ quotation: 'a blurb', post_title: 'Ch 1',
                            post_url: 'https://pub.substack.com/p/ch-1',
                            comment_url: 'https://pub.substack.com/p/ch-1/comment/42',
                            author_name: 'Eva', author_url: 'https://substack.com/@eva',
                            author_user_id: 69847396 }.merge(attrs))
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
    before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: { 'quantity' => ['Bags'], 'superlative' => ['most gnarly'], 'compliment' => ['cracking'] })) }
    subject(:node) { described_class.attribution(quote) }

    it { expect(node['type']).to eq 'paragraph' }
    it { expect(node['content'][0]).to eq('type' => 'text', 'text' => 'Bags of thanks to the ') }
    it { expect(node['content'][1]).to eq('type' => 'text', 'text' => 'most gnarly ') }
    it { expect(node['content'][2]).to eq('type' => 'substack_mention',
                                            'attrs' => { 'id' => 69847396, 'label' => 'eva', 'mentionType' => 'user', 'url' => nil }) }
    it { expect(node['content'][3]).to eq('type' => 'text', 'text' => ", they're ") }
    it { expect(node['content'][4]).to eq('type' => 'text', 'text' => 'cracking', 'marks' => [{ 'type' => 'bold' }, { 'type' => 'italic' }]) }
    it { expect(node['content'][5]).to eq('type' => 'text', 'text' => ", do check 'em out.") }

    describe 'when no quantity is configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: { 'compliment' => ['cracking'] })) }
      it { expect(node['content'][0]['text']).to eq ' of thanks to the ' }
    end

    describe 'when the author has no captured user id' do
      subject(:node) { described_class.attribution(quote(author_user_id: nil)) }
      it { expect(node['content'][2]).to eq('type' => 'text', 'text' => 'Eva',
                                              'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => 'https://substack.com/@eva' } }]) }
    end
  end

  describe '.author' do
    it { expect(described_class.author(quote)).to eq('type' => 'substack_mention',
                                                        'attrs' => { 'id' => 69847396, 'label' => 'eva', 'mentionType' => 'user', 'url' => nil }) }

    it 'uses the unique handle, not the display name shared by many accounts' do
      author = described_class.author(quote(author_name: 'Patrick Mill', author_url: 'https://substack.com/@audiohubstudios'))
      expect(author['attrs']['label']).to eq 'audiohubstudios'
    end

    describe 'when the author has no captured user id' do
      it { expect(described_class.author(quote(author_user_id: nil))).to eq('type' => 'text', 'text' => 'Eva',
                                                                               'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => 'https://substack.com/@eva' } }]) }
    end

    describe "when the author's url doesn't carry a parseable handle" do
      it { expect(described_class.author(quote(author_url: nil))['attrs']['label']).to eq 'Eva' }
    end
  end

  describe '.author_handle' do
    it { expect(described_class.author_handle(quote)).to eq 'eva' }
    it { expect(described_class.author_handle(quote(author_url: 'https://substack.com/@eva/note/c-1'))).to eq 'eva' }
    it { expect(described_class.author_handle(quote(author_url: nil))).to be_nil }
  end

  describe '.more_reviews' do
    subject(:node) { described_class.more_reviews }

    let(:verbs) { ['Enjoy', 'Peruse', 'Snuffle up', 'Savour', 'Yum up', 'Chow down', 'Gnaw', 'Gobble', 'Hoick'] }

    it { expect(node['type']).to eq 'paragraph' }
    it { expect(verbs.any? { |verb| node['content'][0]['text'] == "#{verb} oodles more kudos at my " }).to be true }
    it { expect(node['content'][1]).to eq('type' => 'text', 'text' => 'Reviews Pages', 'marks' => [{ 'type' => 'bold' }, { 'type' => 'italic' }]) }
    it { expect(node['content'][2]).to eq('type' => 'text', 'text' => ', ') }
    it { expect(node['content'][3]).to eq('type' => 'text', 'text' => 'blargh-placeholder-text',
                                            'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => described_class::REVIEWS_URL } }]) }
    it { expect(node['content'][4]).to eq('type' => 'text', 'text' => ':') }
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
    it { expect(described_class.random_compliment).to eq 'cracking' }

    describe 'when none configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      it { expect(described_class.random_compliment).to be_nil }
    end
  end

  describe '.random_quantity' do
    it { expect(described_class.random_quantity).to eq 'bags' }

    describe 'when none configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      it { expect(described_class.random_quantity).to be_nil }
    end
  end

  describe '.random_superlative' do
    before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: { 'superlative' => ['most gnarly'] })) }
    it { expect(described_class.random_superlative).to eq 'most gnarly' }

    describe 'when none configured' do
      before { allow(SubstackSyncConfig).to receive(:instance).and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      it { expect(described_class.random_superlative).to be_nil }
    end
  end
end

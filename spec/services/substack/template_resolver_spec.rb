# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TemplateResolver do
  let(:site) { create :site }
  let(:layout) { create :layout, site: site }
  let(:post) { create :post, site: site, layout: layout }

  def resolve(blocks, **kwargs)
    described_class.resolve(blocks, post: post, **kwargs)
  end

  describe 'literal blocks' do
    it 'passes them through untouched' do
      blocks = [{ 'type' => 'paragraph', 'content' => [] }, { 'type' => 'horizontal_rule' }]
      expect(resolve(blocks)).to eq blocks
    end
  end

  describe 'quotation count substitution' do
    before do
      Array.new(2) do |i|
        SubstackQuotation.create!(quotation: "q#{i}", comment_url: "https://x/comment/#{i}",
                                  post_title: 'P', post_url: 'https://x/p', substack_user: create(:substack_user, name: 'A', handle: 'a'))
      end
    end

    it 'replaces the leading digits of an "N-and-counting" text node with the featurable count' do
      blocks = [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'boasts 141-and-counting reviews' }] }]
      text = resolve(blocks).first['content'].first['text']
      expect(text).to eq 'boasts 2-and-counting reviews'
    end

    it 'replaces the digits of a "N gems and counting" text node with the featurable count' do
      blocks = [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'rock 142 gems and counting. Check out' }] }]
      text = resolve(blocks).first['content'].first['text']
      expect(text).to eq 'rock 2 gems and counting. Check out'
    end

    it 'leaves text without an "and counting" marker untouched' do
      blocks = [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'just some 141 text' }] }]
      text = resolve(blocks).first['content'].first['text']
      expect(text).to eq 'just some 141 text'
    end
  end

  describe 'syncPlatformLinks' do
    subject(:heading) { resolve([{ 'type' => 'syncPlatformLinks', 'attrs' => { 'textAlign' => 'center', 'level' => 4 } }]).first }

    let(:texts) { heading['content'].map { |n| n['text'] } }
    let(:hrefs) { heading['content'].filter_map { |n| n.dig('marks', 0, 'attrs', 'href') } }

    def categorize(label, url)
      category = create :category, site: site, label: label, categorized_type: 'Comfy::Blog::Post'
      create :categorization, category: category, categorized: post, url: url
    end

    before do
      categorize('Quora', 'https://quora/x')
      categorize('FB', 'https://fb/x')
      categorize('Medium', '')
      categorize('Substack', 'https://substack/x')
    end

    it 'is a centred h4' do
      expect(heading['attrs']).to eq('textAlign' => 'center', 'level' => 4)
    end

    it 'leads with My website, then the present platforms in order, separated by middots' do
      expect(texts).to eq ['My website', ' · ', 'Facebook', ' · ', 'Quora']
    end

    it 'links My website to the canonical post url and each platform to its categorization url' do
      expect(hrefs).to eq [post.url.to_s.sub(%r{\A//}, 'https://'), 'https://fb/x', 'https://quora/x']
    end

    context 'when the post has no platform categorizations' do
      before { post.categorizations.delete_all }

      it 'is just My website' do
        expect(texts).to eq ['My website']
      end
    end
  end

  describe 'syncOriginalLink' do
    subject(:heading) { resolve([{ 'type' => 'syncOriginalLink' }]).first }

    it { expect(heading['type']).to eq 'heading' }

    it 'reads "Original: <post url>"' do
      text = heading['content'].map { |n| n['text'] }.join
      expect(text).to start_with('Original: ').and(include(post.url.to_s.sub(%r{\A//}, 'https://')))
    end
  end

  describe 'syncQuotations' do
    let!(:quotations) do
      Array.new(3) do |i|
        SubstackQuotation.create!(quotation: "q#{i}", comment_url: "https://x/comment/#{i}",
                                  post_title: 'P', post_url: 'https://x/p',
                                  substack_user: create(:substack_user, name: 'A', handle: 'a'))
      end
    end

    it 'expands to count triplets (3 blocks each)' do
      result = resolve([{ 'type' => 'syncQuotations', 'attrs' => { 'count' => 2 } }])
      expect(result.size).to eq 6
      expect(result.count { |b| b['type'] == 'blockquote' }).to eq 2
    end

    it 'defaults to three' do
      expect(resolve([{ 'type' => 'syncQuotations' }]).count { |b| b['type'] == 'blockquote' }).to eq 3
    end

    it 'leads each quotation with a post-embed card when a snapshot exists' do
      SubstackQuotation.update_all(post_embed: { 'size' => 'sm', 'id' => 9 })
      result = resolve([{ 'type' => 'syncQuotations', 'attrs' => { 'count' => 1 } }])
      expect(result.map { |b| b['type'] }).to eq %w[digestPostEmbed blockquote heading]
    end

    it 'uses injected quotations when given' do
      injected = [SubstackQuotation.new(quotation: 'inj', post_title: 'P', post_url: 'https://x/p',
                                        substack_user: create(:substack_user, name: 'A', handle: 'a'))]
      result = described_class.resolve([{ 'type' => 'syncQuotations', 'attrs' => { 'count' => 1 } }], post: post, quotations: injected)
      expect(result[1]['content'][0]['content'][0]['text']).to eq '“inj”'
    end
  end

  describe 'syncQuotations excludes the post it renders on' do
    before do
      category = create :category, label: 'Substack', site: site
      create :categorization, category: category, categorized: post, url: 'https://pub/p/self'
      SubstackQuotation.create!(quotation: 'self', comment_url: 'https://x/comment/self', post_title: 'S',
                                post_url: 'https://pub/p/self', substack_user: create(:substack_user, name: 'A', handle: 'a'))
      SubstackQuotation.create!(quotation: 'other', comment_url: 'https://x/comment/other', post_title: 'O',
                                post_url: 'https://pub/p/other', substack_user: create(:substack_user, name: 'B', handle: 'b'))
    end

    it 'renders only quotations from other posts' do
      quotes = resolve([{ 'type' => 'syncQuotations', 'attrs' => { 'count' => 5 } }])
        .select { |b| b['type'] == 'blockquote' }.map { |b| b['content'][0]['content'][0]['text'] }
      expect(quotes).to eq ['“other”']
    end
  end

  describe 'syncIf' do
    let(:block) do
      { 'type' => 'syncIf', 'attrs' => { 'tag' => 'Shite Advice' },
        'content' => [{ 'type' => 'paragraph', 'content' => [] }] }
    end

    context 'when the post has the tag' do
      before { BlogPostTag.without_mirror { post.tags << Tag.create!(name: 'Shite Advice') } }

      it { expect(resolve([block])).to eq block['content'] }
    end

    context 'when the post lacks the tag' do
      it { expect(resolve([block])).to eq [] }
    end
  end
end

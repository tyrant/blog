# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScratchpadParser do

  let(:site) { create :site }
  let(:post) { create :post, site: site, scratchpad: scratchpad }
  let(:ticked) { [] }
  let(:scratchpad) { '' }

  before do
    ticked.each do |label|
      category = Comfy::Cms::Category.find_or_create_by!(label: label, site: site, categorized_type: 'Comfy::Blog::Post')
      create :categorization, category: category, categorized: post
    end
  end

  subject(:result) { described_class.call(post) }

  describe 'Medium' do
    let(:ticked) { ['Medium'] }
    let(:scratchpad) { "https://mikey-clarke.medium.com/speed-broken-ankle-healsies-with-molten-iron-3a1cb39c9c9e" }

    it { expect(result.categorizations['Medium'][:url]).to eq scratchpad }
    it { expect(result.categorizations['Medium'][:data]).to eq({ 'id' => '3a1cb39c9c9e' }) }

    context 'URL carries a postPublishedType query string' do
      let(:scratchpad) { "https://mikey-clarke.medium.com/foo-7a3a3e816061?postPublishedType=repub" }
      it { expect(result.categorizations['Medium'][:url]).to eq 'https://mikey-clarke.medium.com/foo-7a3a3e816061' }
      it { expect(result.categorizations['Medium'][:data]).to eq({ 'id' => '7a3a3e816061' }) }
    end

    context 'only a draft URL present' do
      let(:scratchpad) { "https://medium.com/p/3a1cb39c9c9e/edit" }
      it { expect(result.categorizations['Medium'][:url]).to be_nil }
      it { expect(result.flags).to include(a_string_matching(/Medium ticked/)) }
    end
  end

  describe 'Substack' do
    let(:ticked) { ['Substack'] }
    let(:scratchpad) do
      <<~PAD
        https://mikeyclarke.substack.com/p/how-to-avoid
        Substack id=199807837
        https://substack.com/profile/4619740-mikey-clarke/note/c-267421089
        https://substack.com/@mikeyclarke/note/c-267421568
      PAD
    end

    it { expect(result.categorizations['Substack'][:url]).to eq 'https://mikeyclarke.substack.com/p/how-to-avoid' }
    it { expect(result.categorizations['Substack'][:data]['id']).to eq 199807837 }
    it { expect(result.categorizations['Substack'][:data]['notes'].size).to eq 2 }

    context 'Substask typo and id only in publish URL' do
      let(:scratchpad) do
        <<~PAD
          https://mikeyclarke.substack.com/publish/posts/detail/185487165/share-center
          Substask id=185487165
        PAD
      end
      it { expect(result.categorizations['Substack'][:data]['id']).to eq 185487165 }
    end
  end

  describe 'Twitter' do
    let(:ticked) { ['Twitter'] }
    let(:scratchpad) { "https://twitter.com/pi_neutrino/status/1676664547858595840" }

    it { expect(result.categorizations['Twitter'][:url]).to eq scratchpad }
    it { expect(result.categorizations['Twitter'][:data]).to eq({ 'id' => '1676664547858595840' }) }
  end

  describe 'LinkedIn' do
    let(:ticked) { ['LinkedIn'] }

    context 'urn share URL' do
      let(:scratchpad) { "https://www.linkedin.com/feed/update/urn:li:share:7090091648168161280/" }
      it { expect(result.categorizations['LinkedIn'][:data]).to eq({ 'id' => '7090091648168161280' }) }
    end

    context 'activity URL' do
      let(:scratchpad) { "https://www.linkedin.com/posts/michael-clarke_kratom-activity-6993040209810513920-oDhS" }
      it { expect(result.categorizations['LinkedIn'][:data]).to eq({ 'id' => '6993040209810513920' }) }
    end
  end

  describe 'FB' do
    let(:ticked) { ['FB'] }
    let(:scratchpad) do
      <<~PAD
        https://www.facebook.com/groups/545286786317245/permalink/1943126933199883/?comment_id=1961416284704281
        (reply-reply-comment that the author posted as a separate reply on the same thread)
        https://www.facebook.com/groups/545286786317245/posts/1943126933199883/?comment_id=1961421771370399
      PAD
    end

    it { expect(result.categorizations['FB'][:url]).to match(%r{/permalink/1943126933199883}) }
    it { expect(result.categorizations['FB'][:data]['extras'].first['url']).to match(%r{/posts/1943126933199883}) }
    it { expect(result.categorizations['FB'][:data]['extras'].first['note']).to eq 'reply-reply-comment that the author posted as a separate reply on the same thread' }

    context 'shared only to the personal timeline (no group permalink)' do
      let(:scratchpad) { "https://www.facebook.com/pi.neutrino/posts/10158855736182252" }
      it { expect(result.categorizations['FB'][:url]).to eq scratchpad }
      it { expect(result.categorizations['FB'][:data]).to eq({}) }
      it { expect(result.flags).to be_empty }
    end
  end

  describe 'Quora' do
    let(:ticked) { ['Quora'] }
    let(:scratchpad) do
      <<~PAD
        https://www.quora.com/Some-Question/answer/Someone?comment_id=1
        https://deepthoughts.quora.com/Screenshot-which-deserves?comment_id=2
      PAD
    end

    it { expect(result.categorizations['Quora'][:url]).to match(%r{www\.quora\.com}) }
    it { expect(result.categorizations['Quora'][:data]['extras'].first['url']).to match(%r{deepthoughts\.quora\.com}) }
  end

  describe 'boolean categories' do
    let(:ticked) { ['NSFW', 'Whimsy', 'Shite Advice'] }
    let(:scratchpad) { "https://mikey-clarke.medium.com/x-abc123" }

    it { expect(result.categorizations).to be_empty }
  end

  describe 'untracked links left in scratchpad' do
    let(:ticked) { ['Whimsy'] }
    let(:scratchpad) { "https://en.wikipedia.org/wiki/File:Foo\nhttps://medium.com/p/deadbeef/edit" }

    it { expect(result.leftover).to include('https://en.wikipedia.org/wiki/File:Foo') }
    it { expect(result.leftover).to include('https://medium.com/p/deadbeef/edit') }
  end

end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TagImporter do
  let(:client) { instance_double(Substack::Client) }
  let(:post)   { create :post }

  def substack_categorize(url)
    category = create :category, label: 'Substack', site: post.site
    create :categorization, category: category, categorized: post, url: url
  end

  context 'a published post with tags' do
    subject(:result) { described_class.execute(client: client, pause: 0) }

    before do
      substack_categorize('https://pub.substack.com/p/hello')
      allow(client).to receive(:get_post).with('https://pub.substack.com/p/hello').and_return(
        'postTags' => [{ 'id' => 'uuid-a', 'name' => 'writing' }, { 'id' => 'uuid-b', 'name' => 'advice' }]
      )
    end

    it 'upserts a tag per remote tag' do
      expect { result }.to change(Tag, :count).by(2)
    end

    it 'records the substack uuid' do
      result
      expect(Tag.find_by(name: 'writing').substack_tag_id).to eq 'uuid-a'
    end

    it 'links the tags to the post' do
      result
      expect(post.reload.tags.map(&:name)).to contain_exactly('writing', 'advice')
    end

    it 'reports the links created' do
      expect(result.links_created).to eq 2
    end

    it 'does not mirror imported links back to substack' do
      allow(Substack::TagMirror).to receive(:assign)
      result
      expect(Substack::TagMirror).to_not have_received(:assign)
    end
  end

  context 'a post whose url is not a published /p/ url' do
    before { substack_categorize('https://pub.substack.com/publish/post?id=1') }

    it 'is skipped without an API call' do
      expect(client).to_not receive(:get_post)
      described_class.execute(client: client, pause: 0)
    end
  end

  context 'when get_post fails' do
    before do
      substack_categorize('https://pub.substack.com/p/hello')
      allow(client).to receive(:get_post).and_raise(Substack::Client::Error, 'boom')
    end

    it 'skips the post without raising' do
      expect { described_class.execute(client: client, pause: 0) }.to_not raise_error
    end
  end
end

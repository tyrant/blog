# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::QuotationEmbed do
  let(:client) { instance_double(Substack::Client) }

  let(:post) do
    {
      'id' => 192565792, 'title' => 'A Post', 'cover_image' => 'https://cdn/cover.jpg',
      'canonical_url' => 'https://mikeyclarke.substack.com/p/a', 'post_date' => '2026-03-30T01:44:42.446Z',
      'type' => 'newsletter', 'reaction_count' => 6, 'comment_count' => 1, 'publication_id' => 514910,
      'publishedBylines' => [{
        'id' => 4619740, 'name' => 'Mikey Clarke', 'handle' => 'mikeyclarke', 'bio' => 'bio text',
        'photo_url' => 'https://cdn/me.jpg', 'is_guest' => false, 'bestseller_tier' => nil,
        'publicationUsers' => [{ 'publication' => { 'name' => 'Sexyverse Advice', 'logo_url' => 'https://cdn/logo.png' } }]
      }]
    }
  end

  subject(:attrs) { described_class.execute(post_url: 'https://mikeyclarke.substack.com/p/a', client: client) }

  before { allow(client).to receive(:get_post).with('https://mikeyclarke.substack.com/p/a').and_return(post) }

  it { expect(attrs['size']).to eq 'sm' }
  it { expect(attrs['isEditorNode']).to be true }
  it { expect(attrs['id']).to eq 192565792 }
  it { expect(attrs['title']).to eq 'A Post' }
  it { expect(attrs['cover_image']).to eq 'https://cdn/cover.jpg' }
  it { expect(attrs['reaction_count']).to eq 6 }
  it { expect(attrs['publication_name']).to eq 'Sexyverse Advice' }
  it { expect(attrs['publication_logo_url']).to eq 'https://cdn/logo.png' }
  it { expect(attrs).to_not have_key('nodeId') }

  it 'trims each byline to the editor-stored keys' do
    expect(attrs['publishedBylines'].first.keys).to contain_exactly('id', 'name', 'bio', 'photo_url', 'is_guest', 'bestseller_tier')
  end

  context 'with a blank post url' do
    subject(:attrs) { described_class.execute(post_url: '', client: client) }

    it { expect(attrs).to be_nil }
  end

  context 'when the post fetch fails' do
    before { allow(client).to receive(:get_post).and_raise(Substack::Client::Error, 'boom') }

    it { expect(attrs).to be_nil }
  end
end

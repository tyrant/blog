# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::NavSyncer do
  let(:config) { SubstackSyncConfig.instance }
  let(:client) { instance_double(Substack::Client) }

  subject(:sync) { described_class.execute(client: client, config: config) }

  before do
    config.update!(reviews_draft_id: 111, reviews_extra_draft_ids: [222, 333],
                   publication_host: 'mikeyclarke.substack.com')
    allow(client).to receive(:create_nav_item)
  end

  context 'when some pages have no nav item yet' do
    before do
      allow(client).to receive(:navigation_bar_items)
        .and_return([{ 'post_id' => 111, 'link_title' => 'Reviews Page 1' }])
    end

    it 'creates an item only for the missing pages' do
      sync
      expect(client).to have_received(:create_nav_item)
        .with(link_title: 'Reviews Page 2', link_url: 'https://mikeyclarke.substack.com/p/reviews-page-2')
      expect(client).to have_received(:create_nav_item)
        .with(link_title: 'Reviews Page 3', link_url: 'https://mikeyclarke.substack.com/p/reviews-page-3')
    end

    it 'does not recreate the page that already has an item' do
      sync
      expect(client).to_not have_received(:create_nav_item).with(hash_including(link_title: 'Reviews Page 1'))
    end

    it 'returns the post ids it created items for' do
      expect(sync).to eq [222, 333]
    end

    it 'links page 1 at the /p/reviews slug' do
      config.update!(reviews_extra_draft_ids: [])
      allow(client).to receive(:navigation_bar_items).and_return([])
      sync
      expect(client).to have_received(:create_nav_item)
        .with(link_title: 'Reviews Page 1', link_url: 'https://mikeyclarke.substack.com/p/reviews')
    end
  end

  context 'when every page already has an item' do
    before do
      allow(client).to receive(:navigation_bar_items)
        .and_return([{ 'post_id' => 111 }, { 'post_id' => 222 }, { 'post_id' => 333 }])
    end

    it 'creates nothing' do
      sync
      expect(client).to_not have_received(:create_nav_item)
    end

    it { expect(sync).to eq [] }
  end

  context 'when the current nav cannot be read' do
    before { allow(client).to receive(:navigation_bar_items).and_raise(Substack::Client::Error, 'blocked') }

    it 'creates nothing rather than risk duplicating items' do
      expect { sync }.to raise_error(Substack::Client::Error)
      expect(client).to_not have_received(:create_nav_item)
    end
  end

  context 'without a configured reviews page' do
    before { config.update!(reviews_draft_id: nil) }

    it 'does nothing' do
      expect(client).to_not receive(:navigation_bar_items)
      sync
    end
  end
end

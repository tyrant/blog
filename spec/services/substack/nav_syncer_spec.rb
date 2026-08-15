# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::NavSyncer do
  let(:config) { SubstackSyncConfig.instance }
  let(:client) { instance_double(Substack::Client) }

  subject(:sync) { described_class.execute(client: client, config: config) }

  def item(id, post_id, title: nil, slug: nil)
    { 'id' => id, 'post_id' => post_id, 'link_title' => title, 'post' => (slug ? { 'slug' => slug } : nil) }
  end

  before do
    config.update!(reviews_draft_id: 111, reviews_extra_draft_ids: [222, 333],
                   publication_host: 'mikeyclarke.substack.com')
    allow(client).to receive(:create_nav_item)
    allow(client).to receive(:delete_nav_item)
    allow(client).to receive(:reorder_nav_items)
  end

  describe 'creating missing items' do
    before do
      allow(client).to receive(:navigation_bar_items)
        .and_return([item('a', 111, title: 'Reviews Page 1', slug: 'reviews')])
    end

    it 'creates a bare-numbered item for each page 2+ without one' do
      sync
      expect(client).to have_received(:create_nav_item)
        .with(link_title: '2', link_url: 'https://mikeyclarke.substack.com/p/reviews-page-2')
      expect(client).to have_received(:create_nav_item)
        .with(link_title: '3', link_url: 'https://mikeyclarke.substack.com/p/reviews-page-3')
    end

    it 'does not recreate the page that already has a correctly-labelled item' do
      sync
      expect(client).to_not have_received(:delete_nav_item)
    end

    it 'returns the created post ids' do
      expect(sync).to eq [222, 333]
    end

    it 'labels page 1 "Reviews Page 1" at the /p/reviews slug' do
      config.update!(reviews_extra_draft_ids: [])
      allow(client).to receive(:navigation_bar_items).and_return([])
      sync
      expect(client).to have_received(:create_nav_item)
        .with(link_title: 'Reviews Page 1', link_url: 'https://mikeyclarke.substack.com/p/reviews')
    end
  end

  describe 'relabeling drifted titles' do
    before do
      allow(client).to receive(:navigation_bar_items).and_return([
        item('a', 111, title: 'Reviews Page 1', slug: 'reviews'),
        item('b', 222, title: 'Reviews Page 2', slug: 'reviews-page-2'),
        item('c', 333, title: 'Reviews Page 3', slug: 'reviews-page-3')
      ])
    end

    it 'leaves page 1 untouched (already "Reviews Page 1")' do
      sync
      expect(client).to_not have_received(:delete_nav_item).with('a')
    end

    it 'deletes and recreates pages 2+ with bare-number labels' do
      sync
      expect(client).to have_received(:delete_nav_item).with('b')
      expect(client).to have_received(:create_nav_item).with(link_title: '2', link_url: 'https://mikeyclarke.substack.com/p/reviews-page-2')
      expect(client).to have_received(:delete_nav_item).with('c')
      expect(client).to have_received(:create_nav_item).with(link_title: '3', link_url: 'https://mikeyclarke.substack.com/p/reviews-page-3')
    end
  end

  describe 'pruning stale items' do
    before do
      allow(client).to receive(:navigation_bar_items).and_return([
        item('a', 111, title: 'Reviews Page 1', slug: 'reviews'),
        item('b', 222, title: '2', slug: 'reviews-page-2'),
        item('c', 333, title: '3', slug: 'reviews-page-3'),
        item('gone', 999, title: '4', slug: 'reviews-page-4')
      ])
    end

    it 'deletes a Reviews item whose post is no longer a page' do
      sync
      expect(client).to have_received(:delete_nav_item).with('gone')
    end

    it 'leaves current pages alone' do
      sync
      expect(client).to_not have_received(:delete_nav_item).with('a')
    end

    it 'never deletes a non-Reviews custom item' do
      allow(client).to receive(:navigation_bar_items).and_return([
        item('a', 111, title: 'Reviews Page 1', slug: 'reviews'),
        item('b', 222, title: '2', slug: 'reviews-page-2'),
        item('c', 333, title: '3', slug: 'reviews-page-3'),
        item('shop', 555, title: 'Merch', slug: 'merch')
      ])
      sync
      expect(client).to_not have_received(:delete_nav_item)
    end
  end

  describe 'reordering' do
    it 'reorders the items into reviews_page_ids order' do
      allow(client).to receive(:navigation_bar_items).and_return([
        item('b', 222, title: '2', slug: 'reviews-page-2'),
        item('c', 333, title: '3', slug: 'reviews-page-3'),
        item('a', 111, title: 'Reviews Page 1', slug: 'reviews')
      ])
      sync
      expect(client).to have_received(:reorder_nav_items).with(%w[a b c])
    end

    it 'keeps non-Reviews items ahead of the Reviews block' do
      allow(client).to receive(:navigation_bar_items).and_return([
        item('b', 222, title: '2', slug: 'reviews-page-2'),
        item('shop', 555, title: 'Merch', slug: 'merch'),
        item('a', 111, title: 'Reviews Page 1', slug: 'reviews'),
        item('c', 333, title: '3', slug: 'reviews-page-3')
      ])
      sync
      expect(client).to have_received(:reorder_nav_items).with(%w[shop a b c])
    end

    it 'does not reorder when already in order' do
      allow(client).to receive(:navigation_bar_items).and_return([
        item('a', 111, title: 'Reviews Page 1', slug: 'reviews'),
        item('b', 222, title: '2', slug: 'reviews-page-2'),
        item('c', 333, title: '3', slug: 'reviews-page-3')
      ])
      sync
      expect(client).to_not have_received(:reorder_nav_items)
    end
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

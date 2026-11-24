# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackPendingPublish do
  let(:client) { instance_double(Substack::Client) }

  describe '.record!' do
    it 'records the draft as pending' do
      described_class.record!(42, 'Post')
      expect(described_class.find_by(draft_id: 42).title).to eq 'Post'
    end

    it 'keeps one entry per draft, with the latest title' do
      described_class.record!(42, 'Post')
      described_class.record!(42, 'Renamed')
      expect(described_class.where(draft_id: 42).pluck(:title)).to eq ['Renamed']
    end

    it 'keeps the old title when given none' do
      described_class.record!(42, 'Post')
      described_class.record!(42, nil)
      expect(described_class.find_by(draft_id: 42).title).to eq 'Post'
    end
  end

  describe '.reconcile!' do
    let(:live) do
      { 'is_published' => true, 'title' => 'T', 'draft_title' => 'T', 'subtitle' => 's', 'draft_subtitle' => 's',
        'body' => '{"content":[{"type":"image2","attrs":{"src":"a.png","nodeId":"one"}}]}' }
    end

    let!(:entry) { described_class.create!(draft_id: 42, title: 'Post') }

    def reconcile_with(draft)
      allow(client).to receive(:get_draft).with(42).and_return(draft)
      described_class.reconcile!(client: client)
    end

    it 'clears an entry whose draft is live as-is' do
      reconcile_with(live.merge('draft_body' => live['body']))
      expect(described_class.count).to eq 0
    end

    it 'ignores the image nodeIds Substack regenerates' do
      reconcile_with(live.merge('draft_body' => live['body'].sub('one', 'two')))
      expect(described_class.count).to eq 0
    end

    it 'keeps an entry whose draft body differs' do
      reconcile_with(live.merge('draft_body' => live['body'].sub('a.png', 'b.png')))
      expect(described_class.count).to eq 1
    end

    it 'keeps an entry whose draft subtitle differs' do
      reconcile_with(live.merge('draft_body' => live['body'], 'draft_subtitle' => 'new'))
      expect(described_class.count).to eq 1
    end

    it 'keeps an entry never published' do
      reconcile_with(live.merge('draft_body' => live['body'], 'is_published' => false))
      expect(described_class.count).to eq 1
    end

    it 'keeps entries, without raising, when Substack fails' do
      allow(client).to receive(:get_draft).and_raise(Substack::Client::AuthError, 'dead cookie')
      expect { described_class.reconcile!(client: client) }.to_not raise_error
      expect(described_class.count).to eq 1
    end

    it 'only checks entries in the given scope' do
      expect(client).to_not receive(:get_draft)
      described_class.reconcile!(described_class.where(draft_id: 7), client: client)
    end
  end

  describe '#editor_url' do
    before { SubstackSyncConfig.instance.update_column(:publication_host, 'pub.substack.com') }

    it { expect(described_class.new(draft_id: 7).editor_url).to eq 'https://pub.substack.com/publish/post/7' }
  end
end

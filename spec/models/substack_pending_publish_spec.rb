# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackPendingPublish do
  let(:client) { instance_double(Substack::Client) }

  describe '.publish' do
    context 'when Substack publishes it' do
      before do
        allow(client).to receive(:publish_draft).with(42)
        described_class.create!(draft_id: 42, title: 'Was pending')
      end

      it { expect(described_class.publish(client, 42, title: 'Post')).to be true }

      it 'clears any pending entry for that draft' do
        described_class.publish(client, 42, title: 'Post')
        expect(described_class.where(draft_id: 42)).to be_empty
      end
    end

    context 'when Substack demands a fresh sign-in' do
      before do
        allow(client).to receive(:publish_draft).and_raise(Substack::Client::ReauthRequired, 'reauth')
      end

      it { expect(described_class.publish(client, 42, title: 'Post')).to be false }

      it 'records the draft as pending' do
        described_class.publish(client, 42, title: 'Post')
        expect(described_class.find_by(draft_id: 42).title).to eq 'Post'
      end

      it 'keeps one entry per draft, with the latest title' do
        described_class.publish(client, 42, title: 'Post')
        described_class.publish(client, 42, title: 'Renamed')
        expect(described_class.where(draft_id: 42).pluck(:title)).to eq ['Renamed']
      end
    end

    context 'any other Substack error' do
      before { allow(client).to receive(:publish_draft).and_raise(Substack::Client::AuthError, 'dead cookie') }

      it { expect { described_class.publish(client, 42, title: 'Post') }.to raise_error(Substack::Client::AuthError) }

      it 'records nothing' do
        begin; described_class.publish(client, 42, title: 'Post'); rescue Substack::Client::AuthError; end
        expect(described_class.count).to eq 0
      end
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

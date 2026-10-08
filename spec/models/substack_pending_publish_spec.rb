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

  describe '#editor_url' do
    before { SubstackSyncConfig.instance.update_column(:publication_host, 'pub.substack.com') }

    it { expect(described_class.new(draft_id: 7).editor_url).to eq 'https://pub.substack.com/publish/post/7' }
  end
end

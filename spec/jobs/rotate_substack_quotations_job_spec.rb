# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RotateSubstackQuotationsJob, type: :job do
  let(:client) { instance_double(Substack::Client) }
  let!(:site) { create :site }
  let!(:category) { create :category, label: 'Substack', site: site }
  let!(:post) { create :post, site: site }
  let!(:categorization) { create :categorization, category: category, categorized: post, data: { 'id' => 900 } }
  let!(:quotation) do
    SubstackQuotation.create!(quotation: 'blurb', comment_url: 'https://x/comment/1', author_name: 'Eva',
                              author_url: 'https://substack.com/@eva', post_title: 'P', post_url: 'https://x/p/a')
  end

  def draft(published:)
    existing = SubstackQuotation.new(quotation: 'old', post_title: 'P', post_url: 'https://x/p/a',
                                     author_name: 'A', author_url: 'https://substack.com/@a')
    content = [{ 'type' => 'paragraph', 'content' => [] }] + Substack::QuotationBlock.build(existing) + [{ 'type' => 'horizontal_rule' }]
    { 'id' => 900, 'is_published' => published, 'draft_body' => JSON.generate('type' => 'doc', 'content' => content) }
  end

  before do
    SubstackSyncConfig.instance.update!(quotation_rotation_enabled: true)
    allow(Substack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:update_draft)
    allow(client).to receive(:publish_draft)
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  context 'an unpublished draft' do
    before { allow(client).to receive(:get_draft).with(900).and_return(draft(published: false)) }

    it 'swaps in a fresh quotation triplet' do
      described_class.new.perform
      expect(client).to have_received(:update_draft) do |_id, attrs|
        content = JSON.parse(attrs[:draft_body])['content']
        expect((0...content.size).any? { |i| Substack::QuotationBlock.triplet_at?(content, i) }).to be true
      end
    end

    it 'does not publish an unpublished draft' do
      described_class.new.perform
      expect(client).to_not have_received(:publish_draft)
    end
  end

  context 'a published post' do
    before { allow(client).to receive(:get_draft).with(900).and_return(draft(published: true)) }

    it 'republishes to push the rotation live' do
      described_class.new.perform
      expect(client).to have_received(:publish_draft).with(900)
    end

    it 'stamps the last-rotated time' do
      described_class.new.perform
      expect(SubstackSyncConfig.instance.quotations_rotated_at).to be_present
    end
  end

  context 'when the rotation interval has not elapsed' do
    before { SubstackSyncConfig.instance.update!(quotation_rotation_days: 7, quotations_rotated_at: 2.days.ago) }

    it 'does no work' do
      expect(client).to_not receive(:get_draft)
      described_class.new.perform
    end
  end

  context 'when rotation is disabled' do
    before { SubstackSyncConfig.instance.update!(quotation_rotation_enabled: false) }

    it 'does no work' do
      expect(client).to_not receive(:get_draft)
      described_class.new.perform
    end
  end

  context 'when there are no quotations' do
    before { SubstackQuotation.delete_all }

    it 'does no work' do
      expect(client).to_not receive(:get_draft)
      described_class.new.perform
    end
  end

  context 'when a post errors' do
    before { allow(client).to receive(:get_draft).and_raise(Substack::Client::Error, 'boom') }

    it 'swallows the error and continues' do
      expect { described_class.new.perform }.to_not raise_error
    end
  end
end

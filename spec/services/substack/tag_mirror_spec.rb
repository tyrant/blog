# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TagMirror do
  let(:client) { instance_double(Substack::Client) }
  let(:post)   { create :post }
  let(:tag)    { Tag.create!(name: 'writing', substack_tag_id: 'tag-uuid') }
  let(:join)   { BlogPostTag.new(post: post, tag: tag) }

  def substack_categorize(id)
    category = create :category, label: 'Substack', site: post.site
    create :categorization, category: category, categorized: post, data: { 'id' => id }
  end

  describe '.assign' do
    context 'when the tag is on Substack and the post is synced' do
      before { substack_categorize(900) }

      it 'assigns the tag on the Substack post' do
        expect(client).to receive(:add_tag).with(900, 'tag-uuid')
        described_class.new(join, client: client).assign
      end
    end

    context 'when the tag has no Substack id' do
      let(:tag) { Tag.create!(name: 'shite advice') }

      before { substack_categorize(900) }

      it 'does not call Substack' do
        expect(client).to_not receive(:add_tag)
        described_class.new(join, client: client).assign
      end
    end

    context 'when the post is not synced to Substack' do
      it 'does not call Substack' do
        expect(client).to_not receive(:add_tag)
        described_class.new(join, client: client).assign
      end
    end

    context 'when Substack errors' do
      before do
        substack_categorize(900)
        allow(client).to receive(:add_tag).and_raise(Substack::Client::Error, 'boom')
      end

      it 'swallows the error' do
        expect { described_class.new(join, client: client).assign }.to_not raise_error
      end
    end
  end

  describe '.unassign' do
    before { substack_categorize(900) }

    it 'removes the tag from the Substack post' do
      expect(client).to receive(:remove_tag).with(900, 'tag-uuid')
      described_class.new(join, client: client).unassign
    end
  end
end

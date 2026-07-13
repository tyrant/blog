# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlogPostTag do
  let(:post) { create :post }
  let(:tag)  { Tag.create!(name: 'writing') }

  describe 'associations' do
    it { expect(described_class.new).to respond_to :post }
    it { expect(described_class.new).to respond_to :tag }
  end

  describe 'validations' do
    before { allow(Substack::TagMirror).to receive(:assign) }

    it 'rejects a duplicate tag on the same post' do
      described_class.create!(post: post, tag: tag)
      expect(described_class.new(post: post, tag: tag)).to_not be_valid
    end
  end

  describe 'callbacks' do
    before do
      allow(Substack::TagMirror).to receive(:assign)
      allow(Substack::TagMirror).to receive(:unassign)
    end

    it 'mirrors the assignment to Substack on create' do
      join = described_class.create!(post: post, tag: tag)
      expect(Substack::TagMirror).to have_received(:assign).with(join)
    end

    it 'mirrors the removal to Substack on destroy' do
      join = described_class.create!(post: post, tag: tag)
      join.destroy
      expect(Substack::TagMirror).to have_received(:unassign).with(join)
    end

    it 'suppresses mirroring inside .without_mirror' do
      described_class.without_mirror { described_class.create!(post: post, tag: tag) }
      expect(Substack::TagMirror).to_not have_received(:assign)
    end
  end
end

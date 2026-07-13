# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tag do
  describe 'associations' do
    it { expect(described_class.new).to respond_to :posts }
    it { expect(described_class.new).to respond_to :blog_post_tags }
  end

  describe 'validations' do
    subject { described_class.new(name: 'writing') }

    it { expect(described_class.new).to_not be_valid }
    it { expect(described_class.new(name: 'writing')).to be_valid }

    it 'rejects a case-insensitively duplicate name' do
      described_class.create!(name: 'Writing')
      expect(described_class.new(name: 'writing')).to_not be_valid
    end
  end

  describe '.upsert_from_substack' do
    it 'creates a tag from a name' do
      expect { described_class.upsert_from_substack('advice', 'uuid-1') }.to change(described_class, :count).by(1)
    end

    it 'stores the substack tag id' do
      expect(described_class.upsert_from_substack('advice', 'uuid-1').substack_tag_id).to eq 'uuid-1'
    end

    it 'reuses an existing tag by case-insensitive name' do
      described_class.create!(name: 'Advice')
      expect { described_class.upsert_from_substack('advice', 'uuid-1') }.to_not change(described_class, :count)
    end

    it 'backfills the substack id onto an existing local tag' do
      tag = described_class.create!(name: 'Advice')
      described_class.upsert_from_substack('advice', 'uuid-1')
      expect(tag.reload.substack_tag_id).to eq 'uuid-1'
    end

    it 'keeps the existing id when none is supplied' do
      described_class.create!(name: 'Advice', substack_tag_id: 'uuid-1')
      expect(described_class.upsert_from_substack('advice').substack_tag_id).to eq 'uuid-1'
    end
  end
end

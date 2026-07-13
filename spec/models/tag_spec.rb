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

  describe 'scopes' do
    let!(:whimsy) { described_class.create!(name: 'Whimsy') }
    let!(:nsfw)   { described_class.create!(name: 'NSFW') }
    let!(:sa)     { described_class.create!(name: 'Shite Advice') }
    let!(:other)  { described_class.create!(name: 'advice') }

    describe '.public_names' do
      it { expect(described_class.public_names).to include(whimsy, nsfw, sa) }
      it { expect(described_class.public_names).to_not include(other) }
    end

    describe '.nsfw_first' do
      it { expect(described_class.public_names.nsfw_first.first).to eq nsfw }
      it { expect(described_class.public_names.nsfw_first.to_a[1..]).to contain_exactly(sa, whimsy) }
    end

    describe '.nsfw_banished' do
      it { expect(described_class.public_names.nsfw_banished(true)).to_not include(nsfw) }
      it { expect(described_class.public_names.nsfw_banished(true)).to include(whimsy, sa) }
      it { expect(described_class.public_names.nsfw_banished(false)).to include(nsfw, whimsy, sa) }
    end
  end

  describe '#nsfw?' do
    it { expect(described_class.new(name: 'NSFW')).to be_nsfw }
    it { expect(described_class.new(name: 'Whimsy')).to_not be_nsfw }
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

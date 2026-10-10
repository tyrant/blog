# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackUser do
  describe 'associations' do
    it { is_expected.to have_many(:quotations).class_name('SubstackQuotation').dependent(:nullify) }
    it { is_expected.to have_many(:replies).class_name('SubstackReply').dependent(:nullify) }
  end

  describe 'validations' do
    subject { create :substack_user }

    it { is_expected.to validate_uniqueness_of(:user_id).allow_nil }
    it { is_expected.to validate_uniqueness_of(:handle).case_insensitive.allow_nil }
    it { expect(described_class.new).to_not be_valid }
    it { expect(described_class.new(name: 'Anon')).to be_valid }
  end

  describe 'normalization' do
    it { expect(described_class.new(handle: ' @eva ').handle).to eq 'eva' }
    it { expect(described_class.new(handle: '').handle).to be_nil }
    it { expect(described_class.new(name: '  ').name).to be_nil }
  end

  describe 'callbacks' do
    let(:user) { create :substack_user, name: 'Eva' }
    let!(:quotation) { SubstackQuotation.create!(quotation: 'q', comment_url: 'https://x/comment/1', substack_user: user) }

    before { quotation.update_column(:updated_at, 1.day.ago) }

    context 'a rename' do
      before { user.update!(name: 'Eva Solen') }

      it { expect(quotation.reload.updated_at).to be > 1.minute.ago }
    end

    context 'a new handle' do
      before { user.update!(handle: 'evasolen') }

      it { expect(quotation.reload.updated_at).to be > 1.minute.ago }
    end

    context 'an unrendered change' do
      before { user.update!(user_id: 4242) }

      it { expect(quotation.reload.updated_at).to be < 1.hour.ago }
    end
  end

  describe '#profile_url' do
    it { expect(build(:substack_user, handle: 'eva').profile_url).to eq 'https://substack.com/@eva' }
    it { expect(build(:substack_user, handle: nil).profile_url).to be_nil }
  end

  describe '#absorb!' do
    let(:user) { create :substack_user }
    let(:other) { create :substack_user }
    let!(:quotation) { SubstackQuotation.create!(quotation: 'q', comment_url: 'https://x/comment/1', substack_user: other) }
    let!(:reply) { SubstackReply.create!(target_url: 't', comment_url: 'https://x/comment/2', replied_at: Time.current, substack_user: other) }

    before { user.absorb!(other) }

    it { expect(quotation.reload.substack_user).to eq user }
    it { expect(reply.reload.substack_user).to eq user }
    it { expect(described_class.exists?(other.id)).to be false }
  end

  describe '.identify' do
    it { expect(described_class.identify).to be_nil }

    context 'a new account' do
      subject(:user) { described_class.identify(user_id: 7, handle: 'eva', name: 'Eva') }

      it { expect(user).to have_attributes(user_id: 7, handle: 'eva', name: 'Eva') }
      it { expect(user).to be_persisted }
    end

    context 'a known user id' do
      let!(:known) { create :substack_user, user_id: 7, handle: 'old', name: 'Old Name' }

      subject(:user) { described_class.identify(user_id: 7, handle: 'eva', name: 'Eva') }

      it { expect(user).to eq known }
      it { expect(user.reload).to have_attributes(handle: 'eva', name: 'Eva') }
    end

    context 'a known handle, any case' do
      let!(:known) { create :substack_user, user_id: nil, handle: 'Eva' }

      it { expect(described_class.identify(handle: 'eva')).to eq known }
    end

    context 'blank arguments' do
      let!(:known) { create :substack_user, user_id: 7, handle: 'eva', name: 'Eva' }

      before { described_class.identify(user_id: 7, handle: '', name: nil) }

      it { expect(known.reload).to have_attributes(handle: 'eva', name: 'Eva') }
    end

    context 'a name alone' do
      let!(:known) { create :substack_user, user_id: nil, handle: nil, name: 'Anon' }

      it { expect(described_class.identify(name: 'Anon')).to eq known }
    end

    context 'a name alone matching an identified account' do
      let!(:known) { create :substack_user, name: 'Anon' }

      it { expect(described_class.identify(name: 'Anon')).to_not eq known }
    end

    context 'an id arriving for a handle recorded without one' do
      let!(:handle_only) { create :substack_user, user_id: nil, handle: 'eva' }
      let!(:quotation) { SubstackQuotation.create!(quotation: 'q', comment_url: 'https://x/comment/1', substack_user: handle_only) }
      let!(:with_id) { create :substack_user, user_id: 7, handle: 'eva-old' }

      subject!(:user) { described_class.identify(user_id: 7, handle: 'eva') }

      it { expect(user).to eq with_id }
      it { expect(user.handle).to eq 'eva' }
      it { expect(quotation.reload.substack_user).to eq with_id }
      it { expect(described_class.exists?(handle_only.id)).to be false }
    end

    context 'a handle now owned by a different account' do
      let!(:previous_owner) { create :substack_user, user_id: 8, handle: 'eva' }

      subject!(:user) { described_class.identify(user_id: 7, handle: 'eva') }

      it { expect(user.handle).to eq 'eva' }
      it { expect(previous_owner.reload.handle).to be_nil }
    end
  end

  describe '.alphabetical' do
    let!(:zed) { create :substack_user, name: 'zed' }
    let!(:amy) { create :substack_user, name: 'Amy' }

    it { expect(described_class.alphabetical.to_a).to eq [amy, zed] }
  end

  describe '.search' do
    let!(:eva) { create :substack_user, name: 'Eva Solen', handle: 'evasolen', user_id: 42 }
    let!(:bob) { create :substack_user, name: 'Bob', handle: 'bob' }

    it { expect(described_class.search('solen').to_a).to eq [eva] }
    it { expect(described_class.search('@EVA').to_a).to eq [eva] }
    it { expect(described_class.search('42').to_a).to eq [eva] }
    it { expect(described_class.search('').count).to eq 2 }
  end

  describe '.with_link_counts' do
    let!(:user) { create :substack_user }

    before do
      SubstackQuotation.create!(quotation: 'q', comment_url: 'https://x/comment/1', substack_user: user)
      SubstackReply.create!(target_url: 'https://x/p/y', comment_url: 'https://x/comment/2', replied_at: Time.current, substack_user: user)
    end

    subject(:counted) { described_class.with_link_counts.find(user.id) }

    it { expect(counted.quotations_count).to eq 1 }
    it { expect(counted.replies_count).to eq 1 }
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe 'associations' do
    let(:user) { create :user }

    it { expect(user).to respond_to(:subscribed?) }
    it { expect(user).to respond_to(:subscribe) }
    it { expect(user).to respond_to(:unsubscribe) }
  end

  describe 'factory' do
    let(:user) { build :user }

    it { expect(user).to be_valid }
  end

  describe 'email validation' do
    let(:user) { build :user }

    context 'with duplicate email' do
      before { create :user, email: user.email }

      it { expect(user).to_not be_valid }
      it { expect(user.tap(&:valid?).errors[:email]).to include 'has already been taken' }
    end

    context 'with blank email' do
      before { user.email = '' }

      it { expect(user).to_not be_valid }
      it { expect(user.tap(&:valid?).errors[:email]).to include "can't be blank" }
    end
  end

  describe 'name validation' do
    let(:user) { build :user }

    context 'with blank name' do
      before { user.name = '' }

      it { expect(user).to_not be_valid }
      it { expect(user.tap(&:valid?).errors[:name]).to include "can't be blank" }
    end
  end
end

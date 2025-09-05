require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:email) }
  end

  describe 'associations' do
    # Test the has_subscriptions method from mailkick gem
    it 'has mailkick subscriptions functionality' do
      user = create(:user)
      expect(user).to respond_to(:subscribed?)
      expect(user).to respond_to(:subscribe)
      expect(user).to respond_to(:unsubscribe)
    end
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end
  end

  describe 'email validation' do
    let(:user) { build(:user) }

    context 'with duplicate email' do
      before { create(:user, email: user.email) }
      
      it 'is invalid' do
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end
    end

    context 'with blank email' do
      before { user.email = '' }
      
      it 'is invalid' do
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("can't be blank")
      end
    end
  end

  describe 'name validation' do
    let(:user) { build(:user) }

    context 'with blank name' do
      before { user.name = '' }
      
      it 'is invalid' do
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("can't be blank")
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LandingController', type: :request do
  let(:user_params) { { email: 'test@example.com', name: 'Test User' } }

  describe 'GET /landing' do
    before { get '/landing' }

    it { expect(response).to have_http_status :success }
  end

  describe 'POST /landing/submit' do
    let(:mailer_double) { double('mailer', deliver_later: true) }
    let(:mailer_class_double) { double('mailer_class', thank_you_mail: mailer_double) }

    before { allow(LandingMailer).to receive(:with).and_return(mailer_class_double) }

    context 'with valid user params' do
      it { expect { post '/landing/submit', params: { user: user_params } }.to change(User, :count).by(1) }

      it 'sends thank you email' do
        expect(LandingMailer).to receive(:with).with(user: an_instance_of(User))
        expect(mailer_double).to receive(:deliver_later)
        post '/landing/submit', params: { user: user_params }
      end

      context 'after submission' do
        before { post '/landing/submit', params: { user: user_params } }

        it { expect(response).to have_http_status :success }
      end
    end

    context 'with existing user' do
      let!(:existing_user) { create :user, email: user_params[:email], name: 'Old Name' }

      before { post '/landing/submit', params: { user: user_params } }

      it { expect(existing_user.reload.name).to eq user_params[:name] }
      it { expect { post '/landing/submit', params: { user: user_params } }.to_not change(User, :count) }
    end
  end

  describe 'GET /landing/download' do
    context 'with blank token' do
      before { get '/landing/download', params: { token: '' } }

      it { expect(response).to redirect_to '/landing' }
      it { expect(flash[:notice]).to include "I'd love to send you a free book!" }
    end

    context 'with invalid token' do
      before do
        allow(Tokens::Validator).to receive(:execute).and_return(false)
        get '/landing/download', params: { token: 'invalid_token' }
      end

      it { expect(response).to redirect_to '/landing' }
      it { expect(flash[:notice]).to include "Oh come on, it's been ages" }
    end

    context 'with valid token' do
      before do
        allow(Tokens::Validator).to receive(:execute).and_return(true)
        get '/landing/download', params: { token: 'valid_token' }
      end

      it { expect(response).to have_http_status :success }
      it { expect(response).to_not be_redirect }
    end
  end
end

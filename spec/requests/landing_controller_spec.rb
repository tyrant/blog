require 'rails_helper'

RSpec.describe 'LandingController', type: :request do
  let(:user_params) { { email: 'test@example.com', name: 'Test User' } }

  describe 'GET /landing' do
    it 'renders successfully' do
      get '/landing'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /landing/submit' do
    let(:mailer_double) { double('mailer', deliver_later: true) }
    let(:mailer_class_double) { double('mailer_class', thank_you_mail: mailer_double) }

    before do
      allow(LandingMailer).to receive(:with).and_return(mailer_class_double)
    end

    context 'with valid user params' do
      it 'creates a new user' do
        expect {
          post '/landing/submit', params: { user: user_params }
        }.to change(User, :count).by(1)
      end

      it 'sends thank you email' do
        expect(LandingMailer).to receive(:with).with(user: an_instance_of(User))
        expect(mailer_double).to receive(:deliver_later)
        
        post '/landing/submit', params: { user: user_params }
      end

      it 'renders successfully' do
        post '/landing/submit', params: { user: user_params }
        expect(response).to have_http_status(:success)
      end
    end

    context 'with existing user' do
      let!(:existing_user) { create(:user, email: user_params[:email], name: 'Old Name') }

      it 'updates existing user name' do
        post '/landing/submit', params: { user: user_params }
        existing_user.reload
        expect(existing_user.name).to eq user_params[:name]
      end

      it 'does not create duplicate user' do
        expect {
          post '/landing/submit', params: { user: user_params }
        }.not_to change(User, :count)
      end
    end
  end

  describe 'GET /landing/download' do
    context 'with blank token' do
      it 'redirects with notice' do
        get '/landing/download', params: { token: '' }
        expect(response).to redirect_to('/landing')
        expect(flash[:notice]).to include("I'd love to send you a free book!")
      end
    end

    context 'with invalid token' do
      before do
        allow(Tokens::Validator).to receive(:execute).and_return(false)
      end

      it 'redirects with expired token notice' do
        get '/landing/download', params: { token: 'invalid_token' }
        expect(response).to redirect_to('/landing')
        expect(flash[:notice]).to include("Oh come on, it's been ages")
      end
    end

    context 'with valid token' do
      before do
        allow(Tokens::Validator).to receive(:execute).and_return(true)
      end

      it 'renders successfully without redirect' do
        get '/landing/download', params: { token: 'valid_token' }
        expect(response).to have_http_status(:success)
        expect(response).not_to be_redirect
      end
    end
  end
end

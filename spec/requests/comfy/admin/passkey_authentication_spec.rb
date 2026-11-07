# frozen_string_literal: true

require 'rails_helper'
require 'webauthn/fake_client'

RSpec.describe 'Admin passkey authentication', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:site) { create :site }
  let(:origin) { 'http://www.example.com' }
  let(:fake_client) { WebAuthn::FakeClient.new(origin) }

  before { reset_cms_config }

  around do |example|
    config   = WebAuthn.configuration
    previous = [config.allowed_origins, config.rp_id]
    config.allowed_origins = [origin]
    config.rp_id           = 'www.example.com'
    example.run
  ensure
    config.allowed_origins, config.rp_id = previous
  end

  def basic_auth(name = 'username', pass = 'password')
    { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(name, pass) }
  end

  def register_passkey(nickname: 'MacBook')
    post comfy_admin_passkey_options_path, as: :json
    challenge = response.parsed_body['challenge']
    credential = fake_client.create(challenge: challenge, user_verified: true)
    post comfy_admin_passkeys_path, params: { credential: credential, nickname: nickname }, as: :json
  end

  def sign_in_with_passkey(user_verified: true, challenge: nil)
    post comfy_admin_sign_in_options_path, as: :json
    challenge ||= response.parsed_body['challenge']
    credential = fake_client.get(challenge: challenge, user_verified: user_verified)
    post comfy_admin_sign_in_path, params: { credential: credential }, as: :json
  end

  def recover(token = AdminRecovery.token)
    get comfy_admin_recover_path(token: token)
  end

  describe 'with no passkeys and no session' do
    it 'redirects HTML requests to sign-in' do
      get comfy_admin_tags_path
      expect(response).to redirect_to comfy_admin_sign_in_path
    end

    it 'ignores HTTP Basic credentials' do
      get comfy_admin_tags_path, headers: basic_auth
      expect(response).to redirect_to comfy_admin_sign_in_path
    end

    it 'answers 401 to non-HTML requests, without a Basic challenge' do
      get comfy_admin_tags_path, as: :json
      expect(response).to have_http_status :unauthorized
      expect(response.headers['WWW-Authenticate']).to be_nil
    end

    it 'gates Mission Control too' do
      get '/admin/jobs'
      expect(response).to redirect_to 'http://www.example.com/admin/sign-in'
    end

    it 'shows the console recovery command on the sign-in page' do
      get comfy_admin_sign_in_path
      expect(response).to have_http_status :success
      expect(response.body).to include('Sign in with a passkey', 'AdminRecovery.url')
    end
  end

  describe 'recovery link' do
    it 'signs in for 15 minutes and lands on the passkeys page' do
      recover
      expect(response).to redirect_to comfy_admin_passkeys_path

      get comfy_admin_tags_path
      expect(response).to have_http_status :success

      travel AdminRecovery::TTL + 1.minute do
        get comfy_admin_tags_path
        expect(response).to redirect_to comfy_admin_sign_in_path
      end
    end

    it 'lets you register a passkey, which then signs you in for the long term' do
      recover
      register_passkey

      expect(response).to have_http_status :success
      expect(response.parsed_body['redirect_to']).to eq comfy_admin_passkeys_path
      expect(AdminPasskey.sole.nickname).to eq 'MacBook'

      travel AdminRecovery::TTL + 1.minute do
        get comfy_admin_tags_path
        expect(response).to have_http_status :success
      end
    end

    it 'stops working once a passkey has been added' do
      token = AdminRecovery.token
      recover(token)
      register_passkey
      delete comfy_admin_sign_out_path

      recover(token)
      expect(response).to redirect_to comfy_admin_sign_in_path
      get comfy_admin_tags_path
      expect(response).to redirect_to comfy_admin_sign_in_path
    end

    it 'rejects an expired link' do
      token = AdminRecovery.token
      travel AdminRecovery::TTL + 1.minute do
        recover(token)
        expect(response).to redirect_to comfy_admin_sign_in_path
      end
    end

    it 'rejects a tampered link' do
      recover("#{AdminRecovery.token}x")
      expect(response).to redirect_to comfy_admin_sign_in_path
      get comfy_admin_tags_path
      expect(response).to redirect_to comfy_admin_sign_in_path
    end

    it 'ends on sign-out' do
      recover
      delete comfy_admin_sign_out_path
      get comfy_admin_tags_path
      expect(response).to redirect_to comfy_admin_sign_in_path
    end
  end

  describe 'once a passkey exists' do
    before do
      recover
      register_passkey
      delete comfy_admin_sign_out_path
    end

    it 'signs in and returns to the page that bounced you' do
      get comfy_admin_tags_path
      sign_in_with_passkey

      expect(response).to have_http_status :success
      expect(response.parsed_body['redirect_to']).to eq comfy_admin_tags_path
      expect(AdminPasskey.sole.last_used_at).to be_present

      get comfy_admin_tags_path
      expect(response).to have_http_status :success
    end

    it 'rejects a sign-in without user verification' do
      sign_in_with_passkey(user_verified: false)
      expect(response).to have_http_status :unprocessable_content

      get comfy_admin_tags_path
      expect(response).to redirect_to comfy_admin_sign_in_path
    end

    it 'rejects a sign-in signed over the wrong challenge' do
      sign_in_with_passkey(challenge: WebAuthn::Credential.options_for_get.challenge)
      expect(response).to have_http_status :unprocessable_content
    end

    it 'rejects an unknown passkey' do
      other_client = WebAuthn::FakeClient.new(origin)
      other_client.create(user_verified: true)
      post comfy_admin_sign_in_options_path, as: :json
      credential = other_client.get(challenge: response.parsed_body['challenge'], user_verified: true)
      post comfy_admin_sign_in_path, params: { credential: credential }, as: :json
      expect(response).to have_http_status :unprocessable_content
    end

    it 'sends an already-signed-in visit to the sign-in page on to /admin' do
      sign_in_with_passkey
      get comfy_admin_sign_in_path
      expect(response).to redirect_to '/admin'
    end

    it 'only follows same-site return paths' do
      controller = Comfy::Admin::SessionsController.new
      {
        '/admin/tags?page=2'   => '/admin/tags?page=2',
        '//evil.example/x'     => '/admin',
        '/\\evil.example'      => '/admin',
        'https://evil.example' => '/admin',
        ''                     => '/admin'
      }.each do |stored, expected|
        allow(controller).to receive(:session).and_return({ admin_return_to: stored })
        expect(controller.send(:consume_return_to)).to eq(expected), "for #{stored.inspect}"
      end
    end

    it 'revokes the session when its passkey is removed' do
      sign_in_with_passkey
      delete comfy_admin_passkey_path(AdminPasskey.sole)
      expect(AdminPasskey.count).to eq 0

      get comfy_admin_tags_path
      expect(response).to redirect_to comfy_admin_sign_in_path
    end

    it 'expires the session after the TTL' do
      sign_in_with_passkey
      travel AdminSession::SESSION_TTL + 1.minute do
        get comfy_admin_tags_path
        expect(response).to redirect_to comfy_admin_sign_in_path
      end
    end
  end

  describe 'local development' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('development'))
    end

    it 'skips sign-in for local requests' do
      get comfy_admin_tags_path
      expect(response).to have_http_status :success
    end

    it 'requires sign-in when ADMIN_AUTH_IN_DEV is set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ADMIN_AUTH_IN_DEV').and_return('1')
      get comfy_admin_tags_path
      expect(response).to redirect_to comfy_admin_sign_in_path
    end
  end
end

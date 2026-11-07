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

  def register_passkey(nickname: 'MacBook', headers: {})
    post comfy_admin_passkey_options_path, headers: headers, as: :json
    challenge = response.parsed_body['challenge']
    credential = fake_client.create(challenge: challenge, user_verified: true)
    post comfy_admin_passkeys_path, params: { credential: credential, nickname: nickname }, headers: headers, as: :json
  end

  def sign_in_with_passkey(user_verified: true, challenge: nil)
    post comfy_admin_sign_in_options_path, as: :json
    challenge ||= response.parsed_body['challenge']
    credential = fake_client.get(challenge: challenge, user_verified: user_verified)
    post comfy_admin_sign_in_path, params: { credential: credential }, as: :json
  end

  describe 'before any passkey exists' do
    it 'still accepts HTTP Basic' do
      get comfy_admin_tags_path, headers: http_auth_headers
      expect(response).to have_http_status :success
    end

    it 'rejects wrong HTTP Basic credentials' do
      get comfy_admin_tags_path, headers: {
        'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('username', 'nope')
      }
      expect(response).to have_http_status :unauthorized
    end

    it 'registers a passkey and signs in with it' do
      register_passkey(headers: http_auth_headers)

      expect(response).to have_http_status :success
      expect(response.parsed_body['redirect_to']).to eq comfy_admin_passkeys_path
      expect(AdminPasskey.sole.nickname).to eq 'MacBook'

      # The registration set the passkey session cookie: no Basic header needed.
      get comfy_admin_tags_path
      expect(response).to have_http_status :success
    end
  end

  describe 'once a passkey exists' do
    before do
      register_passkey(headers: http_auth_headers)
      delete comfy_admin_sign_out_path
    end

    it 'refuses HTTP Basic and redirects HTML requests to sign-in' do
      get comfy_admin_tags_path, headers: http_auth_headers
      expect(response).to redirect_to comfy_admin_sign_in_path
    end

    it 'answers 401 to non-HTML requests' do
      get comfy_admin_tags_path, headers: http_auth_headers, as: :json
      expect(response).to have_http_status :unauthorized
    end

    it 'gates Mission Control too' do
      get '/admin/jobs'
      expect(response).to redirect_to 'http://www.example.com/admin/sign-in'
    end

    it 'renders the sign-in page' do
      get comfy_admin_sign_in_path
      expect(response).to have_http_status :success
      expect(response.body).to include 'Sign in with a passkey'
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
      get comfy_admin_tags_path, headers: http_auth_headers
      # The last passkey is gone, so the HTTP Basic bootstrap applies again.
      expect(response).to have_http_status :success
      expect(AdminPasskey.count).to eq 0
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
      AdminPasskey.create!(external_id: 'x', public_key: 'y', nickname: 'Existing')
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

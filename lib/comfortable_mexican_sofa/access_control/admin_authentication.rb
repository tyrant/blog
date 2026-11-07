# frozen_string_literal: true

module ComfortableMexicanSofa::AccessControl
  # Gate for every admin page (and Mission Control at /admin/jobs).
  #
  # - Local dev: open (see AdminSession#admin_dev_bypass?).
  # - Signed in with a passkey: open.
  # - No passkeys registered yet: HTTP Basic with the Comfy credentials, so you
  #   can get in once to register the first passkey at /admin/passkeys.
  # - Otherwise: redirect to the passkey sign-in page. HTTP Basic is refused.
  module AdminAuthentication
    extend ActiveSupport::Concern

    # Set username and password in config/initializers/comfortable_mexican_sofa.rb
    # Like this:
    #   ComfortableMexicanSofa::AccessControl::AdminAuthentication.username = 'myname'
    #   ComfortableMexicanSofa::AccessControl::AdminAuthentication.password = 'mypassword'

    mattr_accessor  :username,
                    :password

    included do
      include ::AdminSession
    end

    def authenticate
      return true if admin_signed_in?
      return authenticate_with_basic_credentials unless AdminPasskey.exists?

      if request.get? && request.format.html?
        session[:admin_return_to] = request.fullpath
        redirect_to main_app.comfy_admin_sign_in_path
      else
        head :unauthorized
      end
    end

    private

    def authenticate_with_basic_credentials
      expected_name = AdminAuthentication.username.to_s
      expected_pass = AdminAuthentication.password.to_s

      result = authenticate_or_request_with_http_basic do |name, pass|
        # Non-short-circuit `&` so both comparisons always run (constant time).
        expected_name.present? && expected_pass.present? &&
          (ActiveSupport::SecurityUtils.secure_compare(name, expected_name) &
            ActiveSupport::SecurityUtils.secure_compare(pass, expected_pass))
      end

      # Set session flag when successfully authenticated
      session[:comfy_admin_authenticated] = true if result

      result
    end
  end
end

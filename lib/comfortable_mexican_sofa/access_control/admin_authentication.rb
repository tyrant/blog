# frozen_string_literal: true

module ComfortableMexicanSofa::AccessControl
  # Gate for every admin page (and Mission Control at /admin/jobs).
  #
  # - Local dev: open (see AdminSession#admin_dev_bypass?).
  # - Signed in with a passkey, or via a console recovery link: open.
  # - Otherwise: HTML GETs redirect to the passkey sign-in page; anything else
  #   gets a bare 401.
  module AdminAuthentication
    extend ActiveSupport::Concern

    included do
      include ::AdminSession
    end

    def authenticate
      return true if admin_signed_in?

      if request.get? && request.format.html?
        session[:admin_return_to] = request.fullpath
        redirect_to main_app.comfy_admin_sign_in_path
      else
        head :unauthorized
      end
    end
  end
end

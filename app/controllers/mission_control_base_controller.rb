# frozen_string_literal: true

# Gates the Mission Control Jobs dashboard behind the same auth as the rest of
# /admin (passkey session, dev bypass, or the HTTP Basic bootstrap).
class MissionControlBaseController < ActionController::Base
  include ComfortableMexicanSofa::AccessControl::AdminAuthentication

  before_action :authenticate
end

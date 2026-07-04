# frozen_string_literal: true

# Gates the Mission Control Jobs dashboard behind the same HTTP basic auth as the
# rest of /admin (the Comfy admin credentials).
class MissionControlBaseController < ActionController::Base
  http_basic_authenticate_with(
    name:     Rails.application.credentials.comfy[:username],
    password: Rails.application.credentials.comfy[:password]
  )
end

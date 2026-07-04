# frozen_string_literal: true

# Gate the dashboard with our own Comfy-admin HTTP basic auth (via the base
# controller) instead of Mission Control's built-in auth. Set the mattrs directly
# so they win over the engine's config sync and are in place before the
# dashboard's controllers load.
MissionControl::Jobs.base_controller_class = "MissionControlBaseController"
MissionControl::Jobs.http_basic_auth_enabled = false

# frozen_string_literal: true

Settings.add_source!(Rails.root.join('config/settings/variables.yml').to_s)
Settings.reload!

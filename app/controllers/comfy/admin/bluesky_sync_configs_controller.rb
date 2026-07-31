# frozen_string_literal: true

class Comfy::Admin::BlueskySyncConfigsController < Comfy::Admin::Cms::BaseController

  before_action :load_config

  def edit
  end

  def update
    if @config.update(config_params)
      flash[:success] = "Bluesky sync settings saved."
      redirect_to edit_comfy_admin_bluesky_sync_config_path
    else
      flash.now[:danger] = "Could not save: #{@config.errors.full_messages.to_sentence}"
      render :edit
    end
  end

  private

  def load_config
    @config = BlueskySyncConfig.instance
  end

  def config_params
    permitted = params.require(:bluesky_sync_config).permit(:handle, :app_password, :service_host, :lead, :lead_shite)
    # A blank app_password means "leave the stored one" — the field renders empty
    # on edit and shouldn't wipe the saved credential.
    permitted.delete(:app_password) if permitted[:app_password].blank?
    permitted
  end

end

# frozen_string_literal: true

class Comfy::Admin::MediumSyncConfigsController < Comfy::Admin::Cms::BaseController

  before_action :load_config

  def edit
  end

  def update
    if @config.update(config_params)
      flash[:success] = "Medium sync settings saved."
      redirect_to edit_comfy_admin_medium_sync_config_path
    else
      flash.now[:danger] = "Could not save Medium sync settings."
      render :edit
    end
  end

  private

  def load_config
    @config = MediumSyncConfig.instance
  end

  def config_params
    params.require(:medium_sync_config).permit(
      :title_template,
      :subtitle,
      :content_template,
      :link_template,
      :footer_html
    )
  end

end

# frozen_string_literal: true

class Comfy::Admin::SubstackSyncConfigsController < Comfy::Admin::Cms::BaseController

  before_action :load_config

  def edit
  end

  def update
    if @config.update(config_params)
      flash[:success] = "Substack sync settings saved."
      redirect_to edit_comfy_admin_substack_sync_config_path
    else
      flash.now[:danger] = "Could not save: #{@config.errors.full_messages.to_sentence}"
      render :edit
    end
  end

  # Pull the subtitle + footer straight from an existing Substack draft/post.
  def recapture
    footer = Substack::FooterCapturer.execute(draft_id: params[:reference_draft_id])
    flash[:success] = "Re-captured subtitle + #{footer.size} footer blocks from draft #{params[:reference_draft_id]}."
  rescue => e
    flash[:danger] = "Re-capture failed: #{e.message}"
  ensure
    redirect_to edit_comfy_admin_substack_sync_config_path
  end

  private

  def load_config
    @config = SubstackSyncConfig.instance
  end

  def config_params
    params.require(:substack_sync_config).permit(:subtitle, :footer_json_text, :quotation_rotation_enabled)
  end

end

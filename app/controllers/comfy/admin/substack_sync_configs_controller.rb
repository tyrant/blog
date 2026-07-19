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
    template = Substack::TemplateCapturer.execute(draft_id: params[:reference_draft_id])
    flash[:success] = "Re-captured subtitle + #{template.size}-block template from draft #{params[:reference_draft_id]}."
  rescue => e
    flash[:danger] = "Re-capture failed: #{e.message}"
  ensure
    redirect_to edit_comfy_admin_substack_sync_config_path
  end

  # Full re-sync of every Substack-linked post on the prod worker.
  def sync_all
    SyncAllSubstackPostsJob.perform_later
    flash[:success] = "Re-syncing all Substack posts on the worker."
    redirect_to edit_comfy_admin_substack_sync_config_path
  end

  private

  def load_config
    @config = SubstackSyncConfig.instance
  end

  def config_params
    params.require(:substack_sync_config).permit(:subtitle, :subtitle_default, :footer_json_text, :quotation_rotation_enabled, :quotation_rotation_days, :reviews_draft_id)
  end

end

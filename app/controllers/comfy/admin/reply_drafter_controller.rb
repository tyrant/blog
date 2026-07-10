# frozen_string_literal: true

class Comfy::Admin::ReplyDrafterController < Comfy::Admin::Cms::BaseController

  def show
    @config = ReplyDrafterConfig.instance
  end

  def generate
    count = params[:count].to_i.clamp(1, 20)
    # Persist the current settings as the new defaults (best-effort — never blocks
    # generation on a validation quibble).
    ReplyDrafterConfig.instance.update(
      instructions: params[:instructions], count: count, split: params[:split], length: params[:length]
    )

    replies = Substack::ReplyGenerator.execute(
      url:          params[:url],
      instructions: params[:instructions],
      count:        count,
      split:        params[:split],
      length:       params[:length]
    )
    render json: { replies: replies }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_content
  end

end

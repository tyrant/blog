# frozen_string_literal: true

class Comfy::Admin::ReplyDrafterController < Comfy::Admin::Cms::BaseController

  def show
  end

  def generate
    replies = Substack::ReplyGenerator.execute(url: params[:url])
    render json: { replies: replies }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_content
  end

end

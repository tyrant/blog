# frozen_string_literal: true

class Comfy::Admin::ReplyTrackerController < Comfy::Admin::Cms::BaseController

  def index
    @by_author = SubstackReply.by_author
  end

  def create
    author = Substack::TargetResolver.execute(url: params[:target_url])
    SubstackReply.create!(
      target_url:     params[:target_url],
      comment_url:    params[:comment_url],
      author_name:    author["name"],
      author_handle:  author["handle"],
      author_user_id: author["user_id"],
      replied_at:     replied_at
    )
    flash[:success] = "Logged reply to #{author["handle"] ? "@#{author["handle"]}" : "the target"}."
  rescue => e
    flash[:danger] = "Could not log reply: #{e.message}"
  ensure
    redirect_to comfy_admin_reply_tracker_path
  end

  private

  def replied_at
    Time.zone.parse(params[:replied_at].to_s).presence || Time.current
  rescue ArgumentError
    Time.current
  end

end

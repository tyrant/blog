# frozen_string_literal: true

class Comfy::Admin::ReplyTrackerController < Comfy::Admin::Cms::BaseController

  def index
    authors  = SubstackReply.by_author(params[:q]).to_a
    @authors = comfy_paginate(Kaminari.paginate_array(authors), per_page: 20)
  end

  def create
    if SubstackReply.exists?(comment_url: params[:comment_url])
      # Skip the API lookup for an already-logged reply.
      flash[:danger] = "That reply is already logged."
    else
      reply = Substack::ReplyResolver.execute(reply_url: params[:comment_url])
      SubstackReply.create!(
        target_url:     reply.target_url,
        comment_url:    params[:comment_url],
        author_name:    reply.author_name,
        author_handle:  reply.author_handle,
        author_user_id: reply.author_user_id,
        replied_at:     reply.replied_at || Time.current,
        target_preview: reply.target_preview,
        reply_preview:  reply.reply_preview,
        ancestor_path:  reply.ancestor_path
      )
      flash[:success] = "Logged reply to #{reply.author_handle ? "@#{reply.author_handle}" : "the target"}."
    end
  rescue => e
    flash[:danger] = "Could not log reply: #{e.message}"
  ensure
    redirect_to comfy_admin_reply_tracker_path
  end

  def destroy
    SubstackReply.find(params[:id]).destroy
    flash[:success] = "Reply deleted."
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Reply not found."
  ensure
    redirect_to comfy_admin_reply_tracker_path
  end

end

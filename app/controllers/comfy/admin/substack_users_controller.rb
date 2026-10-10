# frozen_string_literal: true

class Comfy::Admin::SubstackUsersController < Comfy::Admin::Cms::BaseController

  before_action :load_substack_user, only: %i[edit update destroy]

  def index
    @substack_users = comfy_paginate(SubstackUser.search(params[:q]).with_link_counts.alphabetical, per_page: 20)
  end

  def new
    @substack_user = SubstackUser.new
  end

  def create
    SubstackUser.create!(substack_user_params)
    flash[:success] = "Substack user created."
    redirect_to action: :index
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:danger] = e.record.errors.full_messages.to_sentence
    @substack_user = e.record
    render action: :new
  end

  def edit
  end

  def update
    @substack_user.update!(substack_user_params)
    flash[:success] = "Substack user updated."
    redirect_to action: :index
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:danger] = e.record.errors.full_messages.to_sentence
    render action: :edit
  end

  def destroy
    @substack_user.destroy!
    flash[:success] = "Substack user deleted."
    redirect_to action: :index
  end

  protected

  def load_substack_user
    @substack_user = SubstackUser.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Substack user not found."
    redirect_to action: :index
  end

  def substack_user_params
    params.require(:substack_user).permit(:user_id, :handle, :name)
  end

end

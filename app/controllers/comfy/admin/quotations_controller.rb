# frozen_string_literal: true

class Comfy::Admin::QuotationsController < Comfy::Admin::Cms::BaseController

  def index
    quotations = SubstackQuotation.chronological.to_a
    @quotations = comfy_paginate(Kaminari.paginate_array(quotations), per_page: 25)
  end

  def create
    quotation = SubstackQuotation.new(quotation: params[:quotation], comment_url: params[:comment_url])
    quotation.populate_from_substack!
    quotation.save!
    flash[:success] = "Saved quotation#{quotation.author_name ? " by #{quotation.author_name}" : ""}."
  rescue => e
    flash[:danger] = "Could not save quotation: #{e.message}"
  ensure
    redirect_to comfy_admin_quotations_path
  end

  def destroy
    SubstackQuotation.find(params[:id]).destroy
    flash[:success] = "Quotation deleted."
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Quotation not found."
  ensure
    redirect_to comfy_admin_quotations_path
  end

end

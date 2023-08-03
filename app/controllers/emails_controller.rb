# frozen_string_literal: true

class EmailsController < ApplicationController

  def create
    @email = Email.new(email_params)
    @email.save
    
    render :create
  end

  private

  def email_params
    params.require(:email).permit(:address)
  end
end

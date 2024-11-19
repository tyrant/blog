class LandingMailer < ApplicationMailer

  def thank_you_mail
    @user = params[:user]
    mail(to: @user.email, from: 'omg@sexyverse.email', subject: 'Welcome aboard')
  end
end

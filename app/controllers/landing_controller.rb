class LandingController < ApplicationController

  def index
    @no_nav = true
    @wide_bg = true
  end

  def submit
    # Eh. We've got email uniqueness. This mailing list rigour isn't hideously
    # paramount. If someone submits the same email twice, with different names,
    # let's upsert these names.
    @user = User.find_or_create_by(email: landing_params[:email])
    @user.update(name: landing_params[:name])
    @user.subscribe('list')
    LandingMailer.with(user: @user).thank_you_mail.deliver_later
  end

  def download
    @wide_bg = true
    notice = if params[:token].blank? 
        "I'd love to send you a free book! By all means click that GET MY FREE BOOK NOW button below. I hear it sends you free books."
      elsif !Tokens::Validator.execute(token: params[:token])
        "Oh come on, it's been ages. There's got to be a statute of limitations of some kind on these email links, you know. I'd still love to send you that book, mind you - should you click that GET MY FREE BOOK NOW button below and enter your email again, you'll get emailed a nice fresh download link. Use that."
      end

    redirect_to landing_index_path, notice: notice if notice
  end

  private

  def landing_params
    params.require(:user).permit(:email, :name)
  end
end

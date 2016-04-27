class EmailsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  skip_before_filter :authenticate_user!, only: :create

  def create
    if permitted_params[:secret]!= Setting.receiving_emails.secret
      return render json: { success: false, message: t('error.email.secret_incorrect') }
    end

    Mailman.receive(permitted_params[:email])

    render json: {success: true}
  end

  private
   
  def permitted_params
    params.permit!
  end

end

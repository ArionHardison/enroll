class InvitationsController < ApplicationController
  before_filter :require_login_and_allow_new_account
  
  def claim
    @invitation = Invitation.find(params[:id])

    if @invitation.may_claim?
      @invitation.claim_invitation!(current_user, self)
    else
      flash[:error] = "Invalid invitation."
      redirect_to root_path
    end
  end

  def redirect_to_broker_agency_profile(ba_profile)
    redirect_to broker_agencies_profile_path(ba_profile)
  end

  def redirect_to_employee_match(census_employee)
    redirect_to welcome_insured_employee_index_path
  end

  def redirect_to_employer_profile(employer_profile)
    redirect_to employers_employer_profile_path(employer_profile)
  end

  def require_login_and_allow_new_account
    if current_user.nil?
      session[:portal] = url_for(params)
      redirect_to new_user_registration_url(:invitation_id => params[:id])
    end
  end
end

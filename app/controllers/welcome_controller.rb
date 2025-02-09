# frozen_string_literal: true

class WelcomeController < ApplicationController
  layout 'bootstrap_4'
  skip_before_action :require_login
  before_action :set_cookie_attributes, only: [:index]
  before_action :enable_bs4_layout, only: [:index] if EnrollRegistry.feature_enabled?(:bs4_consumer_flow)

  def show_hints
    current_user.hints = !current_user.hints
    current_user.save
    render json: nil, status: :ok
  end

  def index
  end

  def qna_bot
    render :layout => false
  end

  def form_template
    # created for generic form template access at '/templates/form-template'
  end

  private

  def set_cookie_attributes
    response.headers['Set-Cookie'] = "_session_id=#{session.id}; SameSite=Strict; Secure=true; HttpOnly"
    response.headers['Strict-Transport-Security'] = "max-age=31536000; includeSubDomains; preload"
  end

  def enable_bs4_layout
    @bs4 = true
  end

end

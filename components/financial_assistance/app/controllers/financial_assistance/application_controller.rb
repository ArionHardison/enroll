# frozen_string_literal: true

module FinancialAssistance
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    before_action :verify_financial_assistance_enabled

    helper ::FinancialAssistance::Engine.helpers

    layout "layouts/financial_assistance"

    def load_support_texts
      file_path = lookup_context.find_template("financial_assistance/shared/support_text.yml").identifier
      raw_support_text = YAML.safe_load(File.read(file_path)).with_indifferent_access
      @support_texts = support_text_placeholders raw_support_text
    end

    private

    def find_application
      application_id = params[:application_id] || params[:id]
      @application = if current_user.try(:person).try(:agent?) && !session[:person_id].present?
                       FinancialAssistance::Application.find_by(id: application_id)
                     else
                       FinancialAssistance::Application.find_by(id: application_id, :family_id.in => get_current_person.current_and_past_financial_assistance_identifiers)
                     end
    end

    # For security reasons, only set the financial assistance identifier as the FA application's family_id
    # if the current user as an HBX Admin. This will also prevent a nil financial assistance identifier
    # in the event of impersonation from an admin not working properly
    def financial_assistance_identifiers
      get_current_person.current_and_past_financial_assistance_identifiers
    end

    def verify_financial_assistance_enabled
      return render(file: 'public/404.html', status: 404) unless ::EnrollRegistry.feature_enabled?(:financial_assistance)
      true
    end

    def support_text_placeholders(raw_support_text)
      return [] if @application.nil?
      raw_support_text.update(raw_support_text).each do |_key, value|
        value.gsub! '<application-applicable-year>', @application.assistance_year.to_s if value.include? '<application-applicable-year>'
      end
    end
  end
end

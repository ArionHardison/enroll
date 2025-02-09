# frozen_string_literal: true

module FinancialAssistance
  # Applicant controller for Financial Assistance
  class ApplicantsController < FinancialAssistance::ApplicationController

    before_action :find, :find_application, :except => [:age_of_applicant] #except the ajax requests
    before_action :find_applicant, only: [:age_of_applicant]
    before_action :set_cache_headers, only: [:other_questions, :tax_info]
    before_action :enable_bs4_layout, only: [:edit, :other_questions, :tax_info]

    # This is a before_action that checks if the application is a renewal draft and if it is, it sets a flash message and redirects to the applications_path
    # This before_action needs to be called after finding the application
    #
    # @before_action
    # @private
    before_action :check_for_uneditable_application

    def new
      authorize @application, :new?
      @bs4 = true if params[:bs4] == "true"
      @applicant = FinancialAssistance::Forms::Applicant.new(:application_id => params.require(:application_id))

      respond_to do |format|
        format.html
        format.js
      end
    end

    def create
      authorize @application, :create?
      sanitized_applicant_params
      @applicant = FinancialAssistance::Forms::Applicant.new(params.require(:applicant).permit(*applicant_parameters))
      @applicant.application_id = params[:application_id]
      @applicant.is_dependent = params[:is_dependent]
      success, _result = @applicant.save

      respond_to do |format|
        if success
          format.js { render js: "window.location = '#{edit_application_path(@application)}'"}
        else
          load_support_texts
          format.js { render 'new' }
        end
      end
    end

    def edit
      authorize @applicant, :edit?

      %w[home mailing].each{|kind| @applicant.addresses.build(kind: kind) if @applicant.addresses.in(kind: kind).blank?}
      @vlp_doc_subject = @applicant.vlp_subject

      respond_to do |format|
        format.html
        format.js
      end
    end

    def update
      authorize @applicant, :update?

      if params[:financial_assistance_applicant].present?
        format_date_params params[:financial_assistance_applicant]
        @applicant.update_attributes!(permit_params(params[:financial_assistance_applicant]))
        head :ok, content_type: "text/html"
      else
        sanitized_applicant_params
        @applicant = FinancialAssistance::Forms::Applicant.new(params.require(:applicant).permit(*applicant_parameters))
        @applicant.is_dependent = params[:is_dependent]
        @applicant.application_id = params[:application_id]
        @applicant.applicant_id = params[:id]
        @applicant.save

        redirect_to edit_application_path(@application)
      end
    end

    def other_questions
      authorize @applicant, :other_questions?
      save_faa_bookmark(request.original_url)
      set_admin_bookmark_url
      @applicant = @application.active_applicants.find(params[:id])

      respond_to do |format|
        format.html { render layout: @bs4 ? 'financial_assistance_progress' : 'financial_assistance_nav' }
      end
    end

    def save_questions
      authorize @applicant, :save_questions?
      format_date_params params[:applicant] if params[:applicant].present?
      @applicant = @application.active_applicants.find(params[:id])
      @applicant.assign_attributes(permit_params(params[:applicant])) if params[:applicant].present?
      if @applicant.save(context: :other_qns)
        redirect_to edit_application_path(@application)
      else
        @applicant.save(validate: false)
        flash[:error] = build_error_messages_for_other_qns(@applicant)
        redirect_to other_questions_application_applicant_path(@application, @applicant)
      end
    end

    def tax_info
      authorize @applicant, :step?
      save_faa_bookmark(request.original_url)
      set_admin_bookmark_url
      layout = @bs4 ? 'financial_assistance_progress' : 'financial_assistance_nav'
      respond_to do |format|
        format.html { render layout: layout }
      end
    end

    def save_tax_info
      authorize @applicant, :step?
      @applicant = @application.active_applicants.find(params[:id])
      @applicant.update_attributes(permit_params(params[:applicant])) if params[:applicant].present?

      if @applicant.save(context: :tax_info)
        redirect_to application_applicant_incomes_path(@application, @applicant)
      else
        @applicant.save(validate: false)
        flash[:error] = build_error_messages_for_tax_info(@applicant)
        redirect_to tax_info_application_applicant_path(@application, @applicant)
      end
    end

    def step
      raise ActionController::UnknownFormat unless request.format.html?

      authorize @applicant, :step?
      redirect_to tax_info_application_applicant_path(@application, @applicant)
    end

    def age_of_applicant
      authorize @applicant, :age_of_applicant?

      respond_to do |format|
        format.js { render :plain => @applicant.age_of_the_applicant.to_s }
      end
    end

    def applicant_is_eligible_for_joint_filing
      applicant_id = params[:applicant_id]
      applicant = FinancialAssistance::Applicant.find(applicant_id)

      authorize applicant, :applicant_is_eligible_for_joint_filing?

      # applicant is primary and spouse exists?
      @result = if applicant.is_primary_applicant
                  primary_applicant_has_spouse
                else
                  # applicant is spouse of primary?
                  applicant_is_spouse_of_primary(applicant)
                end

      respond_to do |format|
        format.text { render plain: @result }
      end
    end

    def immigration_document_options
      @bs4 = true if params[:bs4] == "true"
      if params[:target_type] == "FinancialAssistance::Applicant" && params[:target_id].present?
        @target = FinancialAssistance::Applicant.find(params[:target_id])
        authorize @target, :immigration_document_options?
        # vlp_docs = @target.applicant.vlp_documents
      else
        @target = FinancialAssistance::Forms::Applicant.new
        authorize @application, :new?
      end

      @vlp_doc_target = params[:vlp_doc_target]
      # vlp_doc_subject = params[:vlp_doc_subject]
      # @country = vlp_docs.detect{|doc| doc.subject == vlp_doc_subject }.try(:country_of_citizenship) if vlp_docs
      respond_to :js
    end

    def destroy
      authorize @applicant, :destroy?
      ::FinancialAssistance::Operations::Applicants::Destroy.new.call(@applicant)
      redirect_to edit_application_path(@application)
    end

    private

    def sanitized_applicant_params
      applicant_params = params.permit(:applicant => {})[:applicant].to_h

      if applicant_params["is_applying_coverage"] == 'false'
        fields_to_unset = {
          us_citizen: nil,
          naturalized_citizen: nil,
          eligible_immigration_status: nil,
          is_incarcerated: nil,
        }

        fields_to_unset.each do |field, value|
          applicant_params[field.to_s] = value
        end
      end

      params[:applicant] = applicant_params
    end

    def applicant_is_spouse_of_primary(applicant)
      has_spouse_relationship = applicant.relationships.where(kind: 'spouse', relative_id: @application.primary_applicant.id).count > 0
      has_spouse_relationship.to_s
    end

    def primary_applicant_has_spouse
      @application.primary_applicant.relationships.where(kind: 'spouse').present? ? 'true' : 'false'
    end

    def find_applicant
      @applicant = ::FinancialAssistance::Application.find(
        params[:application_id]
      ).applicants.find(params[:applicant_id])

      @application = @applicant&.application
    end

    def format_date_params(model_params)
      model_params["pregnancy_due_on"] = parse_date(model_params["pregnancy_due_on"].to_s) if model_params["pregnancy_due_on"].present?
      model_params["pregnancy_end_on"] = parse_date(model_params["pregnancy_end_on"].to_s) if model_params["pregnancy_end_on"].present?
      model_params["student_status_end_on"] = parse_date(model_params["student_status_end_on"].to_s) if model_params["student_status_end_on"].present?

      model_params["person_coverage_end_on"] = parse_date(model_params["person_coverage_end_on"].to_s) if model_params["person_coverage_end_on"].present?
      model_params["medicaid_cubcare_due_on"] = parse_date(model_params["medicaid_cubcare_due_on"].to_s) if model_params["medicaid_cubcare_due_on"].present?
      model_params = format_nil_for_blank_date(model_params)

      model_params["dependent_job_end_on"] = parse_date(model_params["dependent_job_end_on"].to_s) if model_params["dependent_job_end_on"].present?
    end

    def build_error_messages_for_tax_info(model)
      model.valid?(:tax_info) ? nil : model.errors.messages.first[1][0].titleize
    end

    def build_error_messages(model)
      model.valid?("step_#{@current_step.to_i}".to_sym) ? nil : model.errors.messages.first[1][0].titleize
    end

    def build_error_messages_for_other_qns(model)
      model.valid?(:other_qns) ? nil : model.errors.messages.first[1][0].titleize
    end

    def find
      # TODO: Not sure about this, added the @model definition because it wasn't defined
      @applicant = find_application.active_applicants.where(id: params[:id]).last || find_application.applicants.last || nil
      @model = @applicant
    end

    def permit_params(attributes)
      attributes.permit!
    end

    def applicant_parameters
      params = [
        :first_name,
        :last_name,
        :middle_name,
        :name_pfx,
        :name_sfx,
        :dob,
        :ssn,
        :gender,
        :is_applying_coverage,
        :us_citizen,
        :naturalized_citizen,
        :indian_tribe_member,
        :eligible_immigration_status,
        :tribal_id,
        :tribal_state,
        :tribal_name,
        :is_incarcerated,
        :relationship,
        :is_consumer_role,
        :same_with_primary,
        :no_dc_address,
        :is_temporarily_out_of_state,
        :is_homeless,
        :no_ssn,
        :vlp_subject, :citizenship_number, :naturalization_number,
        :alien_number, :passport_number, :sevis_id, :visa_number,
        :receipt_number, :expiration_date, :card_number, :description,
        :i94_number, :country_of_citizenship,
        { :tribe_codes => [] },
        { :addresses_attributes => [:kind, :address_1, :address_2, :city, :state, :zip, :id, :_destroy] },
        { :phones_attributes => [:kind, :full_phone_number, :id, :_destroy] },
        { :emails_attributes => [:kind, :address, :id, :_destroy],
          :ethnicity => [], :immigration_doc_statuses => [] }
        ]
      address_hash = params.find {|key| key.is_a?(Hash) && key[:addresses_attributes]}
      address_hash[:addresses_attributes] << :county if EnrollRegistry.feature_enabled?(:display_county) && address_hash.present?
      params
    end

    def format_nil_for_blank_date(model_params)
      model_params["medicaid_cubcare_due_on"] = nil if model_params.key?("medicaid_cubcare_due_on") && model_params["medicaid_cubcare_due_on"].blank?
      model_params["has_eligibility_changed"] = nil if model_params.key?("has_eligibility_changed") && model_params["has_eligibility_changed"].blank? && !model_params["has_eligibility_changed"].nil?
      model_params["has_household_income_changed"] = nil if model_params.key?("has_household_income_changed") && model_params["has_household_income_changed"].blank? && !model_params["has_household_income_changed"].nil?
      model_params
    end

    def enable_bs4_layout
      @bs4 = true if EnrollRegistry.feature_enabled?(:bs4_consumer_flow)
    end
  end
end

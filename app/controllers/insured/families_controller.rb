class Insured::FamiliesController < FamiliesController
  include VlpDoc
  include Acapi::Notifiers
  include ::ApplicationHelper
  include Config::SiteConcern
  include Insured::FamiliesHelper

  layout :resolve_layout
  before_action :enable_bs4_layout, only: [:home, :find_sep, :record_sep, :check_qle_date, :check_move_reason, :check_marriage_reason,
                                           :check_insurance_reason, :verification, :personal, :inbox, :manage_family, :brokers, :enrollment_history]
  before_action :updateable?, only: [:delete_consumer_broker, :record_sep, :purchase, :upload_notice]
  before_action :init_qualifying_life_events, only: [:home, :manage_family, :find_sep]
  before_action :check_for_address_info, only: [:find_sep, :home]
  before_action :check_employee_role
  before_action :find_or_build_consumer_role, only: [:home]
  before_action :calculate_dates, only: [:check_move_reason, :check_marriage_reason, :check_insurance_reason]
  before_action :can_view_entire_family_enrollment_history?, only: [:display_all_hbx_enrollments]
  before_action :transition_family_members_update_params, only: [:transition_family_members_update]
  before_action :upload_notice_form_enabled?, only: [:upload_notice_form]
  before_action :set_cache_headers, only: [:home, :inbox]
  before_action :ivl_osse_enabled?, only: [
    :healthcare_for_childcare_program,
    :healthcare_for_childcare_program_form,
    :update_osse_eligibilities
  ]

  around_action :cache_hbx, only: [:home]

  def home
    authorize @family, :home?
    build_employee_role_by_census_employee_id
    set_flash_by_announcement
    set_bookmark_url
    set_admin_bookmark_url(home_insured_families_path)
    @active_sep = @family.latest_active_sep

    # rubocop:disable Lint/RedundantStringCoercion
    log("#3717 person_id: #{@person.id}, params: #{params.to_s}, request: #{request.env.inspect}", {:severity => "error"}) if @family.blank?
    # rubocop:enable Lint/RedundantStringCoercion

    @hbx_enrollments = @family.enrollments.non_external.order(effective_on: :desc, submitted_at: :desc, coverage_kind: :desc) || []

    @all_hbx_enrollments_for_admin = if EnrollRegistry.feature_enabled?(:include_external_enrollment_in_display_all_enrollments)
                                       @hbx_enrollments + HbxEnrollment.family_canceled_enrollments(@family) + HbxEnrollment.family_external_enrollments(@family)
                                     else
                                       @hbx_enrollments + HbxEnrollment.family_canceled_enrollments(@family)
                                     end

    @enrollment_filter = @family.enrollments_for_display
    valid_display_enrollments = []
    @enrollment_filter.each  { |e| valid_display_enrollments.push e['_id'] }

    log("#3860 person_id: #{@person.id}", {:severity => "error"}) if @hbx_enrollments.any?{|hbx| !hbx.is_coverage_waived? && hbx.product.blank?}
    update_changing_hbxs(@hbx_enrollments)

    @hbx_enrollments += HbxEnrollment.family_non_pay_enrollments(@family) if EnrollRegistry.feature_enabled?(:show_non_pay_enrollments)

    @employee_role = @person.active_employee_roles.first if is_shop_or_fehb_market_enabled?
    @tab = params['tab']
    @family_members = @family.active_family_members

    if EnrollRegistry.feature_enabled?(:home_tiles_current_and_future_only)
      @hbx_enrollments = @hbx_enrollments.select { |d| d["effective_on"] >= TimeKeeper.date_of_record.beginning_of_year }
      @all_hbx_enrollments_for_admin = @all_hbx_enrollments_for_admin.select { |d| d["effective_on"] >= TimeKeeper.date_of_record.beginning_of_year }
    end

    # Sort by effective_on and coverage kind again. The latest enrollment will display at the top in order of health -> dental.
    @all_hbx_enrollments_for_admin = @all_hbx_enrollments_for_admin&.sort_by{|enr| [enr.effective_on, enr.coverage_kind]}&.reverse
    @hbx_enrollments = @hbx_enrollments&.sort_by{|enr| [enr.effective_on, enr.coverage_kind]}&.reverse!

    respond_to do |format|
      format.html
      format.any { head :ok }
    end
  end

  def enrollment_history
    authorize @family, :enrollment_history?

    redirect_to main_app.family_account_path(tab: 'home') unless EnrollRegistry.feature_enabled?(:enrollment_history_page)

    @hbx_enrollments = @family.enrollments.non_external.order(effective_on: :desc, submitted_at: :desc, coverage_kind: :desc) || []
    @hbx_enrollments += HbxEnrollment.family_non_pay_enrollments(@family)

    @all_hbx_enrollments_for_admin = if EnrollRegistry.feature_enabled?(:include_external_enrollment_in_display_all_enrollments)
                                       @hbx_enrollments + HbxEnrollment.family_canceled_enrollments(@family) + HbxEnrollment.family_external_enrollments(@family)
                                     else
                                       @hbx_enrollments + HbxEnrollment.family_canceled_enrollments(@family)
                                     end
    # Sort by effective_on again. The latest enrollment will display at the top.
    @all_hbx_enrollments_for_admin = @all_hbx_enrollments_for_admin.uniq&.sort_by{|enr| [enr.effective_on, enr.coverage_kind]}&.reverse
    @hbx_enrollments = @hbx_enrollments&.sort_by{|enr| [enr.effective_on, enr.coverage_kind]}&.reverse!

    respond_to do |format|
      format.html
      format.any { head :ok }
    end
  end

  def manage_family
    authorize @family, :manage_family?

    set_bookmark_url
    set_admin_bookmark_url(manage_family_insured_families_path)
    @family_members = @family.active_family_members
    @resident = @person.is_resident_role_active?
    # @employee_role = @person.employee_roles.first
    @tab = params['tab']


    respond_to do |format|
      format.html
    end
  end

  def brokers
    authorize @family, :brokers?

    @tab = params['tab']
    @employee_role = @person.active_employee_roles.first if @person.active_employee_roles.present?

    respond_to :html
  end

  def find_sep
    authorize @family, :find_sep?

    @hbx_enrollment_id = params[:hbx_enrollment_id]
    @change_plan = params[:change_plan]
    @employee_role_id = params[:employee_role_id]

    @common_seps = @qualifying_life_events&.common
    @rare_seps = @qualifying_life_events&.rare

    @resident_role_id = if params[:resident_role_id].present? && params[:resident_role_id]
                          params[:resident_role_id]
                        else
                          @person.try(:resident_role).try(:id)
                        end

    @next_ivl_open_enrollment_date = HbxProfile.current_hbx.try(:benefit_sponsorship).try(:renewal_benefit_coverage_period).try(:open_enrollment_start_on)

    @market_kind = (params[:employee_role_id].present? && params[:employee_role_id] != 'None') ? 'shop' : 'individual'
    @market_kind = "coverall" if (params[:resident_role_id].present? && params[:resident_role_id]) || @resident_role_id

    respond_to do |format|
      format.html { render :layout => EnrollRegistry.feature_enabled?(:bs4_consumer_flow) ? "progress" : "application" }
    end
  end

  def record_sep
    authorize @family, :record_sep?

    if params[:qle_id].present?
      qle = QualifyingLifeEventKind.find(params[:qle_id])
      special_enrollment_period = @family.special_enrollment_periods.new(effective_on_kind: params[:effective_on_kind])
      special_enrollment_period.selected_effective_on = Date.strptime(params[:effective_on_date], "%m/%d/%Y") if params[:effective_on_date].present?
      special_enrollment_period.qualifying_life_event_kind = qle
      special_enrollment_period.qle_on = parse_date(params[:qle_date])
      special_enrollment_period.market_kind = qle.market_kind == "individual" ? "ivl" : qle.market_kind
      special_enrollment_period.save
    end

    action_params = {person_id: @person.id, consumer_role_id: @person.consumer_role.try(:id), employee_role_id: params[:employee_role_id], enrollment_kind: 'sep', effective_on_date: special_enrollment_period.effective_on, qle_id: qle.id}
    action_params.merge!({change_plan: "change_plan"}) if @family.enrolled_hbx_enrollments.any?

    redirect_to new_insured_group_selection_path(action_params)
  end

  def personal
    authorize @family, :personal?

    @tab = params['tab']
    @contact_preferences_mapping = ConsumerRole::CONTACT_METHOD_MAPPING.invert unless EnrollRegistry.feature_enabled?(:contact_method_via_dropdown)
    @family_members = @family.active_family_members
    @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(@person.consumer_role) if @person.is_consumer_role_active?
    @person.consumer_role.build_nested_models_for_person if @person.is_consumer_role_active?
    @person.resident_role.build_nested_models_for_person if @person.is_resident_role_active?
    @resident = @person.is_resident_role_active?

    respond_to do |format|
      format.html
      format.js
    end
  end

  def inbox
    authorize @family, :inbox?

    @tab = params['tab']
    @folder = params[:folder] || 'Inbox'
    @sent_box = false
    @provider = @person
    @family_members = @family.active_family_members

    respond_to :html
  end

  def healthcare_for_childcare_program
    authorize @family, :healthcare_for_childcare_program?

    @childcare_forms = ::Forms::HealthcareForChildcareProgramForm.build_forms_for(@person.primary_family)
    respond_to :html
  end

  def event_logs
    authorize @family, :can_view_audit_log?
    @tab = params['tab']
    hbxes = @family.family_members.map {|fm| fm.person.hbx_id}&.uniq
    @event_logs = EventLogs::MonitoredEvent.where(:subject_hbx_id.in => hbxes)&.order(:event_time.desc)&.map(&:eligibility_details)
    respond_to :html
  end

  def healthcare_for_childcare_program_form
    authorize @family, :healthcare_for_childcare_program?

    @service = ::Services::IvlOsseEligibilityService.new(params.permit(:person_id))
    @osse_status_by_year = @service.osse_status_by_year
    respond_to :html
  end

  def update_osse_eligibilities
    authorize @family, :healthcare_for_childcare_program?
    args = params.require(:eligibilities).permit(:person_id, :osse => {})
    @service = ::Services::IvlOsseEligibilityService.new(args)
    result = @service.update_osse_eligibilities_by_year

    flash[:notice] = "Sucessfully updated #{@service.person.full_name}'s HC4CC eligibility for years #{result['Success'].join(', ')}" if result["Success"]
    flash[:error] = "Failed to updated #{@service.person.full_name}'s HC4CC eligibility for years #{result['Failure'].join(', ')}" if result["Failure"]

    redirect_to(healthcare_for_childcare_program_form_insured_families_path(person_id: @service.person.id))
  end

  def verification
    authorize @family, :verification?

    @family_members = @person.primary_family.has_active_consumer_family_members
    respond_to :html
  end

  def upload_application
    authorize @family, :upload_application?

    @family_members = @person.primary_family.has_active_resident_family_members
    respond_to :html
  end

  def check_qle_date
    authorize @family, :check_qle_date?

    today = TimeKeeper.date_of_record
    start_date = today - 30.days
    end_date = today + 30.days
    @qle_event_date = parse_date(params[:date_val])

    if params[:qle_id].present?
      @qle = QualifyingLifeEventKind.find(params[:qle_id])
      @qle_date = @qle.qle_event_date_kind == :qle_on ? @qle_event_date : today
      start_date = today - @qle.post_event_sep_in_days.try(:days)
      end_date = today + @qle.pre_event_sep_in_days.try(:days)
      @qle_reason_val = params[:qle_reason_val] if params[:qle_reason_val].present?
      @qle_end_on = @qle_date + @qle.post_event_sep_in_days.try(:days)
    end
    @qle_date ||= if @qle
                    @qle.qle_event_date_kind == :qle_on ? @qle_event_date : today
                  else
                    @qle_event_date
                  end
    @qualified_date = if @qle && @qle.coverage_start_on.present? && @qle.coverage_end_on.present?
                        (@qle.coverage_start_on..@qle.coverage_end_on).cover?(@qle_date)
                      else
                        (start_date..end_date).cover?(@qle_date)
                      end
    if @person.has_active_employee_role? && !(@qle.present? && @qle.individual?)
      @future_qualified_date = (@qle_date > today) ? true : false
    end

    @resident_role_id = @person.resident_role.id if @person.resident_role?

    employee_role = @person.active_employee_roles.first

    return unless @qle.present? && employee_role.present? && (@qle.shop? || @qle.fehb?) && !@qualified_date && params[:qle_id].present?

    benefit_application = employee_role.employer_profile.active_benefit_application
    reporting_deadline = @qle_date > today ? today : @qle_date + 30.days
    # TODO: Figure out how to refactor this with ResourceRegistry
    case EnrollRegistry[:enroll_app].setting(:site_key).item
    when :cca
      trigger_notice_observer(employee_role, benefit_application, 'employee_notice_for_sep_denial', qle_title: @qle.title, qle_reporting_deadline: reporting_deadline.strftime("%m/%d/%Y"), qle_event_on: @qle_event_date.strftime("%m/%d/%Y"))
    when :dc
      event_name = @person.has_multiple_active_employers? ? 'sep_denial_notice_for_ee_active_on_multiple_rosters' : 'sep_denial_notice_for_ee_active_on_single_roster'
      trigger_notice_observer(employee_role, benefit_application, event_name, qle_title: @qle.title, qle_reporting_deadline: reporting_deadline.strftime("%m/%d/%Y"), qle_event_on: @qle_event_date.strftime("%m/%d/%Y"))
    end

    respond_to :js
  end

  def sep_zip_compare
    authorize @family, :sep_zip_compare?

    old_zip = params[:old_zip].strip
    new_zip = params[:new_zip].strip
    is_approved = false

    old_county_zip = BenefitMarkets::Locations::CountyZip.where(zip: old_zip).first
    new_county_zip = BenefitMarkets::Locations::CountyZip.where(zip: new_zip).first

    if new_county_zip.present?
      if old_county_zip.present?
        old_service_area_ids = ::BenefitMarkets::Locations::ServiceArea.service_areas_for(
          ::Address.new(zip: old_county_zip.zip, county: old_county_zip.county_name, state: 'ME')
        ).map(&:issuer_provided_code)

        new_service_area_ids = ::BenefitMarkets::Locations::ServiceArea.service_areas_for(
          ::Address.new(zip: new_county_zip.zip, county: new_county_zip.county_name, state: 'ME')
        ).map(&:issuer_provided_code)

        is_approved = (old_service_area_ids.sort != new_service_area_ids.sort)
      else
        is_approved = true
      end
    end

    respond_to do |format|
      format.json { render json: {is_approved: is_approved} }
    end
  end

  def check_move_reason
    authorize @family, :check_qle_reason?
    respond_to :js
  end

  def check_insurance_reason
    authorize @family, :check_qle_reason?
    respond_to :js
  end

  def check_marriage_reason
    authorize @family, :check_qle_reason?
    respond_to :js
  end

  def purchase
    if params[:hbx_enrollment_id].present?
      @enrollment = HbxEnrollment.find(params[:hbx_enrollment_id])
    elsif @family.present?
      @enrollment = @family.active_household.hbx_enrollments.active.last
    end
    @family ||= @enrollment&.family
    authorize @family, :purchase?

    if @enrollment.present?
      @enrollment.reset_dates_on_previously_covered_members
      if @enrollment.is_shop?
        @plan = @enrollment.product
        @member_group = HbxEnrollmentSponsoredCostCalculator.new(@enrollment).groups_for_products([@plan]).first
      else
        @plan = @enrollment.build_plan_premium
      end

      begin
        @plan.name
      rescue StandardError => e
        log("#{e.message};  #3742 plan: #{@plan}, family_id: #{@family.id}, hbx_enrollment_id: #{@enrollment.id}", {:severity => "error"})
      end

      @enrollable = @family.is_eligible_to_enroll?

      @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
      @terminate = params[:terminate].present? ? params[:terminate] : ''
      @terminate_date = fetch_terminate_date(params["terminate_date_#{@enrollment.hbx_id}"]) if @terminate.present?
      @terminate_reason = params[:terminate_reason] || ''
      respond_to do |format|
        format.html { render :layout => 'application' }
      end
    else
      redirect_to :back
    end
  end

  # admin manually uploads a notice for person
  def upload_notice
    authorize @family, :upload_notice?

    if !params[:file] || !params[:subject]
      flash[:error] = "File or Subject not provided"
      redirect_back(fallback_location: :back)
      return
    end

    unless valid_file_upload?(params[:file], FileUploadValidator::PDF_TYPE)
      redirect_back(fallback_location: :back)
      return
    end

    doc_uri = Aws::S3Storage.save(file_path, 'notices')

    if doc_uri.present?
      notice_document = Document.new({title: file_name, creator: "hbx_staff", subject: "notice", identifier: doc_uri,
                                      format: file_content_type})
      begin
        @person.documents << notice_document
        @person.save!
        send_notice_upload_notifications(notice_document, params[:subject])
        flash[:notice] = "File Saved"
      rescue StandardError
        flash[:error] = "Could not save file."
      end
    else
      flash[:error] = "Could not save file."
    end

    redirect_back(fallback_location: :back)
    nil
  end

  # displays the form to upload a notice for a person
  def upload_notice_form
    authorize @family, :upload_notice_form?

    @notices = @person.documents.where(subject: 'notice')
    respond_to :html
  end

  def delete_consumer_broker
    @family = Family.find(params[:id])
    authorize @family, :delete_consumer_broker?

    broker_agency = @family&.current_broker_agency

    if broker_agency.present?
      @family&.notify_broker_update_on_impacted_enrollments_to_edi({family_id: @family&.id.to_s})
      broker_agency.destroy
      redirect_to :action => "home", flash: {notice: "Successfully deleted."}
    else
      redirect_to :action => "home", flash: {notice: "Unable to remove expert from this account"}
    end
  end

  def transition_family_members
    authorize @family, :transition_family_members?

    @row_id = params[:family_actions_id]
    @family_members = @family.active_family_members
    @non_shop_market_kinds = Person::NON_SHOP_ROLES
    respond_to do |format|
      format.js { render "insured/families/transition_family_members" }
    end
  end

  def transition_family_members_update
    authorize @family, :transition_family_members?

    @row_id = params[:family_actions_id]
    params_parser = ::Forms::BulkActionsForAdmin.new(params.permit(@permitted_param_keys).to_h)
    @result = params_parser.result
    @row = params_parser.row
    @family_id = params_parser.family_id
    params_parser.transition_family_members
    @family = Family.find(params[:family])
    @consumer_people = []
    @resident_people = []
    @result[:success].each do |person|
      @resident_people << person.id.to_s if person.individual_market_transitions.order("created_at DESC").first.role_type == "resident"
      @consumer_people << person.id.to_s if person.individual_market_transitions.order("created_at DESC").first.role_type == "consumer"
    end
    trigger_ivl_to_cdc_transition_notice if @resident_people.present?
    trigger_cdc_to_ivl_transition_notice  if @consumer_people.present?

    respond_to do |format|
      format.js { render "insured/families/transition_family_members_result.js.erb"}
    end
  end

  private

  def healthcare_for_childcare_program_params
    params.require(:forms_healthcare_for_childcare_program_form).permit(:osse_eligibility, :person_id)
  end

  def upload_notice_form_enabled?
    redirect_to(root_path, notice: "Upload Notice Form is Disabled") unless EnrollRegistry.feature_enabled?(:show_upload_notices)
  end

  def transition_family_members_update_params
    dynamic_transition_params_keys = params.keys.map { |key| key.match(/transition_.*/) }.compact.map(&:to_s).map(&:to_sym)
    non_dynamic_params_keys = [:family, :family_actions_id, :qle_id, :action]
    @permitted_param_keys = dynamic_transition_params_keys.push(non_dynamic_params_keys).flatten
  end

  def fetch_terminate_date(terminate_date)
    term_date = @family.terminate_date_for_shop_by_enrollment(@enrollment)
    return term_date unless terminate_date.present?

    begin
      Date.strptime(terminate_date, "%m/%d/%Y")
    rescue StandardError
      term_date
    end
  end

  def can_view_entire_family_enrollment_history?
    authorize Family, :can_view_entire_family_enrollment_history?
  end

  def trigger_ivl_to_cdc_transition_notice
    person =  @family.primary_applicant.person
    begin
      IvlNoticesNotifierJob.perform_later(person.id.to_s, "ivl_to_coverall_transition_notice", {family: @family.id.to_s, result: {:people => @resident_people}})
    rescue Exception => e
      Rails.logger.error { "Unable to deliver transition notice #{person.hbx_id} due to #{e.inspect}" }
    end
  end

  def trigger_cdc_to_ivl_transition_notice
    person = @family.primary_applicant.person
    begin
      IvlNoticesNotifierJob.perform_later(person.id.to_s, "coverall_to_ivl_transition_notice", {family: @family.id.to_s, result: {:people => @consumer_people}})
    rescue Exception => e
      Rails.logger.error { "Unable to deliver transition notice #{person.hbx_id} due to #{e.inspect}" }
    end
  end

  # rubocop:disable Style/ExplicitBlockArgument
  def cache_hbx
    Caches::CurrentHbx.with_cache do
      yield
    end
  end
  # rubocop:enable Style/ExplicitBlockArgument

  def updateable?
    authorize Family, :updateable?
  end

  def check_employee_role
    return unless is_shop_or_fehb_market_enabled?
    employee_role_id = (params[:employee_id].present? && params[:employee_id].include?('employee_role')) ? params[:employee_id].gsub("employee_role_", "") : nil

    @employee_role = employee_role_id.present? ? @person.active_employee_roles.detect{|e| e.id.to_s == employee_role_id} : @person.active_employee_roles.first
  end

  def build_employee_role_by_census_employee_id
    return unless is_shop_or_fehb_market_enabled?
    census_employee_id = (params[:employee_id].present? && params[:employee_id].include?('census_employee')) ? params[:employee_id].gsub("census_employee_", "") : nil
    return if census_employee_id.nil?

    census_employee = CensusEmployee.find_by(id: census_employee_id)
    if census_employee.present?
      census_employee.construct_employee_role_for_match_person
      @employee_role = census_employee.employee_role
      @person.reload
    end
  end

  def find_or_build_consumer_role
    @family.check_for_consumer_role
  end

  def init_qualifying_life_events
    begin
      raise if @person.nil?
    rescue StandardError => e
      message = "no person in init_qualifying_life_events"
      message += "stacktrace: #{e.backtrace}"
      log(message, {:severity => "error"})
      raise e
    end

    employee_qle_market_scope = nil
    if @person.has_multiple_roles?
      @multiroles = @person.has_multiple_roles?
      employee_role = @person.active_employee_roles.first
      @manually_picked_role = ["individual_market_events", "fehb_market_events", "shop_market_events"].include?(params[:market]) ? params[:market] : "shop_market_events"

      if is_shop_or_fehb_market_enabled?
        employee_qle_market_scope = "shop_market_events"
        employee_qle_market_scope = "fehb_market_events" if employee_role && employee_role.market_kind == "fehb"
      end

      if current_user.has_hbx_staff_role?
        @qualifying_life_events = QualifyingLifeEventKind.send "#{employee_qle_market_scope}_admin" if @manually_picked_role == "shop_market_events" && is_shop_or_fehb_market_enabled?
        manual_individual_events = QualifyingLifeEventKind.send "#{@manually_picked_role}_without_transition_member_action" if @manually_picked_role == "individual_market_events"
        @qualifying_life_events = if @qualifying_life_events.present?
                                    @qualifying_life_events.or(manual_individual_events)
                                  else
                                    manual_individual_events
                                  end
      elsif @manually_picked_role == "individual_market_events"
        @qualifying_life_events = QualifyingLifeEventKind.individual_market_events
      elsif @manually_picked_role && employee_qle_market_scope.present?
        @qualifying_life_events = QualifyingLifeEventKind.send employee_qle_market_scope
      end
    elsif @person.active_employee_roles.present? || @person.consumer_role.present? || @person.resident_role.present?
      role = if @person.active_employee_roles.present? && is_shop_or_fehb_market_enabled?
               @person.active_employee_roles.first
             elsif is_individual_market_enabled?
               @person.consumer_role || @person.resident_role
             end
      @qualifying_life_events = QualifyingLifeEventKind.qualifying_life_events_for(role, current_user.has_hbx_staff_role?)
    end
  end

  def check_for_address_info
    if @person.has_active_employee_role?
      redirect_to edit_insured_employee_path(@person.active_employee_roles.first) if @person.addresses.blank?
    elsif @person.is_consumer_role_active?
      if !(@person.addresses.present? || (@person.is_homeless || @person.is_temporarily_out_of_state))
        redirect_to edit_insured_consumer_role_path(@person.consumer_role)
      elsif ridp_redirection
        redirect_to ridp_agreement_insured_consumer_role_index_path
      end
    end
  end

  def ridp_redirection
    return false if current_user.has_hbx_staff_role?
    consumer = @person.consumer_role
    not_verified = !RemoteIdentityProofingStatus.is_complete_for_consumer_role?(consumer)
    @person.user && not_verified
  end

  def update_changing_hbxs(hbxs)
    if hbxs.present?
      changing_hbxs = hbxs.changing
      changing_hbxs.update_all(changing: false) if changing_hbxs.present?
    end
  end

  def file_path
    params[:file]&.tempfile
  end

  def file_name
    params[:file]&.original_filename
  end

  def file_content_type
    params[:file]&.content_type
  end

  def send_notice_upload_notifications(notice, subject)
    notice_upload_email
    notice_upload_secure_message(notice, subject)
  end

  def notice_upload_email
    if (@person.consumer_role.present? && @person.consumer_role.can_receive_electronic_communication?) ||
       (@person.employee_roles.present? && (@person.employee_roles.map(&:contact_method) & ["Only Electronic communications", "Paper and Electronic communications"]).any?)
      UserMailer.generic_notice_alert(@person.first_name, "You have a new message from #{site_short_name}", @person.work_email_or_best).deliver_now
    end
  end

  def notice_upload_secure_message(notice, subject)
    body = "<br>You can download the notice by clicking this link " +
           "<a href=" + "#{authorized_document_download_path('Person', @person.id, 'documents',
                                                             notice.id)}?content_type=#{notice.format}&filename=#{notice.title.gsub(/[^0-9a-z]/i,'')}.pdf&disposition=inline" + " target='_blank'>" + subject + "</a>"

    @person.inbox.messages << Message.new(subject: subject, body: body, from: site_short_name)
    @person.save!
  end

  def calculate_dates
    @qle_event_date = parse_date(params[:date_val])
    @qle = QualifyingLifeEventKind.find(params[:qle_id])
    @qle_date = @qle.qle_event_date_kind == :qle_on ? @qle_event_date : TimeKeeper.date_of_record
    start_date = TimeKeeper.date_of_record - @qle.post_event_sep_in_days.try(:days)
    end_date = TimeKeeper.date_of_record + @qle.pre_event_sep_in_days.try(:days)
    @qualified_date = if @qle && @qle.coverage_start_on.present? && @qle.coverage_end_on.present?
                        (@qle.coverage_start_on..@qle.coverage_end_on).cover?(@qle_date)
                      else
                        (start_date..end_date).cover?(@qle_date)
                      end
    @qle_date_calc = @qle_date - aca_qle_period.days

    @resident_role_id = @person.resident_role.id if @person.resident_role?
  end

  def conditionally_bs4_enabled_actions
    %i[record_sep check_qle_date check_move_reason check_marriage_reason check_insurance_reason personal]
  end

  def enable_bs4_layout
    @bs4 = conditionally_bs4_enabled_actions.include?(action_name) ? params[:bs4] == "true" : true if EnrollRegistry.feature_enabled?(:bs4_consumer_flow)
  end
end

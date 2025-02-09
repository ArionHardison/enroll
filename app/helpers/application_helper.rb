# frozen_string_literal: true

module ApplicationHelper
  include FloatHelper
  include ::FinancialAssistance::VerificationHelper
  include HtmlScrubberUtil
  include DropdownHelper
  include L10nHelper

  def add_external_links_enabled?
    EnrollRegistry.feature_enabled?(:add_external_links)
  end

  def plan_shopping_enabled?
    add_external_links_enabled? && EnrollRegistry[:add_external_links].setting(:plan_shopping_display).item
  end

  # Returns an array wth the appropriate application type items
  # used in app/views/insured/consumer_roles/_form.html.erb
  # _application_types_list.html.erb
  def consumer_role_application_type_options(person)
    options_array = []
    if person.primary_family.e_case_id.present? && !(person.primary_family.e_case_id.include? "curam_landing")
      options_array << [EnrollRegistry[:curam_application_type].item, EnrollRegistry[:curam_application_type].item]
      options_array
    elsif pundit_allow(ConsumerRole, :can_view_application_types?)
      options_array = EnrollRegistry[:application_type_options].item.map do |option|
        if option == 'State Medicaid Agency'
          ['State Medicaid Agency', 'Curam']
        else
          [option, option]
        end
      end
    end
    options_array << ['In Person', 'In Person'] if EnrollRegistry.feature_enabled?(:in_person_application_enabled)
    # Phone and Paper should always display
    options_array << ["Phone", "Phone"]
    options_array << ["Paper", "Paper"]
    selected = if person.primary_family.e_case_id.present? && !(person.primary_family.e_case_id.include? "curam_landing")
                 'Curam'
               else
                 person.primary_family.application_type
               end
    [options_array.uniq, {selected: selected}]
  end

  def seed_url_helper(row)
    case row.record_class_name
    when nil
      "Not Yet Seeded"
    when 'Family'
      # TODO: Change from root url to family home page
      link_to_with_noopener_noreferrer(
        "#{row.target_record&.primary_person&.full_name} (Family Primary Person)",
        resume_enrollment_exchanges_agents_path(person_id: row&.target_record&.primary_applicant&.person&.id)
      )
    end
  end

  def home_page_path
    return unless current_user
    if current_user.has_hbx_staff_role?
      main_app.exchanges_hbx_profiles_root_path
    elsif current_user.identity_verified? || (current_user.has_consumer_role? && current_user.person.consumer_role.identity_verified?)
      main_app.family_account_path
    end
  end

  def can_employee_shop?(date)
    return false if date.blank?
    date = Date.strptime(date.to_s,"%m/%d/%Y")
    Plan.has_rates_for_all_carriers?(date) == false
  end

  def rates_available?(employer, date = nil)
    employer.applicant? && !Plan.has_rates_for_all_carriers?(date) ? "blocking" : ""
  end

  def product_rates_available?(benefit_sponsorship, date = nil)
    date = Date.strptime(date.to_s, '%m/%d/%Y') if date.present?
    return false if benefit_sponsorship.present? && benefit_sponsorship.active_benefit_application.present?
    date ||= BenefitSponsors::BenefitApplications::BenefitApplicationSchedular.new.calculate_start_on_dates[0]
    benefit_sponsorship.applicant? && BenefitMarkets::Forms::ProductForm.for_new(date).fetch_results.is_late_rate
  end

  def deductible_display(hbx_enrollment, plan)
    if hbx_enrollment.hbx_enrollment_members.size > 1
      plan.family_deductible.split("|").last.squish
    else
      plan.deductible
    end
  end

  def draft_plan_year?(plan_year)
    plan_year if plan_year.aasm_state == "draft" && plan_year.try(:benefit_groups).empty?
  end

  def get_portals_text(insured, employer, broker)
    my_portals = []
    my_portals << "<strong>Insured</strong>" if insured == true
    my_portals << "<strong>Employer</strong>" if employer == true
    my_portals << "<strong>Broker</strong>" if broker == true
    my_portals.to_sentence
  end

  def copyright_notice
    copyright_attribution = if TimeKeeper.date_of_record.year.to_s == site_copyright_period_start.to_s
                              "#{site_copyright_period_start} #{EnrollRegistry[:enroll_app].setting(:long_name).item}"
                            else
                              "#{site_copyright_period_start}-#{TimeKeeper.date_of_record.year} #{EnrollRegistry[:enroll_app].setting(:long_name).item}"
                            end
    raw("<span class='copyright'><i class='far fa-copyright fa-lg' aria-hidden='true'></i> #{copyright_attribution}. All Rights Reserved. </span>")
  end

  def menu_tab_class(a_tab, current_tab)
    (a_tab == current_tab) ? raw(" class=\"active\"") : ""
  end

  #Purchased enrollment family premium (family home page - view details button on the enrollment)
  def current_cost(hbx_enrollment = nil, source = nil)
    # source is account or shopping
    return unless source == 'account' && hbx_enrollment.present? && hbx_enrollment.coverage_kind == 'health'

    (hbx_enrollment.total_premium - hbx_enrollment.applied_aptc_amount.to_f)
  end

  #Shopping enrollment family premium (plan shopping page)
  # rubocop:disable Style/OptionalBooleanParameter
  def shopping_group_premium(plan_cost, plan_ehb_cost, subsidy_amount, can_use_aptc = true)
    return (plan_cost - subsidy_amount).round(2) unless session['elected_aptc'].present? && session['max_aptc'].present? && can_use_aptc

    aptc_amount = session['elected_aptc'].to_f
    cost = float_fix(plan_cost - [plan_ehb_cost, aptc_amount].min - subsidy_amount)
    cost > 0 ? cost.round(2) : 0
  end
  # rubocop:enable Style/OptionalBooleanParameter

  def min_premium_with_aptc(plan_cost, plan_ehb_cost, subsidy_amount, can_use_aptc)
    can_use_aptc ||= false
    premium = shopping_group_premium(plan_cost, plan_ehb_cost, subsidy_amount, can_use_aptc)
    premium > 1 ? premium : 1
  end

  def link_to_with_noopener_noreferrer(name, path, options = {})
    link_to(name, path, options.merge(rel: 'noopener noreferrer'))
  end

  def datepicker_control(f, field_name, options = {}, value = "")
    sanitized_field_name = field_name.to_s.sub(/\?$/,"")
    opts = options.dup
    obj_name = f.object_name
    obj_val = f.object.send(field_name.to_sym)
    current_value = if obj_val.blank?
                      value
                    else
                      obj_val.is_a?(DateTime) ? obj_val.strftime("%m/%d/%Y") : obj_val
                    end
    html_class_list = opts.delete(:class) { |_k| "" }
    jq_tag_classes = (html_class_list.split(/\s+/) + ["jq-datepicker"]).join(" ")
    generated_field_name = "jq_datepicker_ignore_#{obj_name}[#{sanitized_field_name}]"
    provided_id = options[:id] || options["id"]
    generate_target_id = nil
    generated_target_id = "#{provided_id}_jq_datepicker_plain_field" unless provided_id.blank?
    sanitized_object_name = "#{obj_name}_#{sanitized_field_name}".delete(']').tr('^-a-zA-Z0-9:.', "_")
    generated_target_id ||= "#{sanitized_object_name}_jq_datepicker_plain_field"
    capture do
      concat f.text_field(field_name, opts.merge(:class => html_class_list, :id => generated_target_id, :value => obj_val.try(:to_s, :db)))
      concat text_field_tag(generated_field_name, current_value, opts.merge(:class => jq_tag_classes, :start_date => "07/01/2016", :style => "display: none;", "data-submission-field" => "##{generated_target_id}"))
    end
  end

  # rubocop:disable Style/IdenticalConditionalBranches
  # rubocop:disable Style/StringConcatenation
  def generate_breadcrumbs(breadcrumbs)
    html = "<ul class='breadcrumb'>"
    breadcrumbs.each_with_index do |breadcrumb, index|
      if breadcrumb[:path]
        html += "<li>" + link_to(breadcrumb[:name], breadcrumb[:path], data: breadcrumb[:data])
        html += "<span class='divider'></span>" if index < breadcrumbs.length - 1
        html += "</li>"
      else
        html += "<li class='active #{breadcrumb[:class]}'>" + breadcrumb[:name]
        html += "<span class='divider'></span>" if index < breadcrumbs.length - 1
        html += "</li>"
      end
    end
    html += "</ul>"
    sanitize_html(html)
  end
  # rubocop:enable Style/IdenticalConditionalBranches
  # rubocop:enable Style/StringConcatenation

  # Formats version information in HTML string for the referenced object instance
  def version_for_record(obj)
    ver  = "version: #{obj.version}" if obj.respond_to?('version')
    date = "updated: #{format_date(obj.updated_at)}" if obj.respond_to?('updated_at')
    who  = "by: #{obj.updated_by}" if obj.respond_to?('updated_by')
    [ver, date, who].reject(&:nil? || empty?).join(' | ')
  end

  def format_date(date_value)
    date_value.strftime("%m/%d/%Y") if date_value.respond_to?(:strftime)
  end

  def format_datetime(date_value)
    date_value.to_time.strftime("%m/%d/%Y %H:%M %Z %:z") if date_value.respond_to?(:strftime)
  end

  def group_xml_transmitted_message(employer)
    employer.xml_transmitted_timestamp.present? ? "The group xml for employer #{employer.legal_name} was transmitted on #{format_time_display(employer.xml_transmitted_timestamp)}. Are you sure you want to transmit again?" : "Are you sure you want to transmit the group xml for employer #{employer.legal_name}?"
  end

  def format_time_display(timestamp)
    timestamp.present? ? timestamp.in_time_zone('Eastern Time (US & Canada)') : ""
  end

  # Builds a Dropdown button
  def select_dropdown(input_id, list)
    return unless list.is_a? Array
    content_tag(:select, class: "form-control", id: input_id) do
      concat(content_tag(:option, "Select", value: ""))
      list.each do |item|
        if item.is_a? Array
          concat(content_tag(:option, item[0], value: item[1]))
        else
          concat(content_tag(:option, item.humanize, value: item))
        end
      end
    end
  end

  # Formats first data row in a table indicating an empty set
  def table_empty_to_human
    content_tag(:tr, content_tag(:td, "None given"))
  end

  def transaction_status_to_label(ed)
    if ed.open?
      content_tag(:span, ed.aasm_state.to_s, class: "label label-warning")
    elsif ed.assigned?
      content_tag(:span, ed.aasm_state.to_s, class: "label label-info")
    else
      content_tag(:span, ed.aasm_state.to_s, class: "label label-success")
    end
  end

  # Formats a full name into upper/lower case with last name wrapped in HTML <strong> tag
  def name_to_listing(person)
    given_name = [person.first_name, person.middle_name].reject(&:nil? || empty?).join(' ')
    sir_name  = content_tag(:strong, mixed_case(person.last_name))
    raw([mixed_case(given_name), sir_name, person.name_sfx].reject(&:nil? || empty?).join(' '))
  end

  # Formats each word in a string to capital first character and lower case for all other characters
  def mixed_case(str)
    str&.downcase&.gsub(/\b\w/, &:upcase)
  end

  # Formats a boolean value into 'Yes' or 'No' string
  def boolean_to_human(test)
    test ? "Yes" : "No"
  end

  # Uses a boolean value to return an HTML checked/unchecked glyph
  def boolean_to_glyph(test)
    test ? content_tag(:span, "", class: "far fa-check-square aria-hidden='true'") : content_tag(:span, "", class: "far fa-square aria-hidden='true'")
  end

  # Uses a boolean value to return an HTML checked/unchecked glyph with hover text
  def prepend_glyph_to_text(test)
    if test.event_name
      sanitize_html("<i class='fa fa-link' data-toggle='tooltip' title='#{test.event_name}'></i>&nbsp;&nbsp;&nbsp;&nbsp;#{link_to test.notice_number, notifier.preview_notice_kind_path(test), target: '_blank'}")
    else
      sanitize_html("<i class='fa fa-link' data-toggle='tooltip' style='color: silver'></i>&nbsp;&nbsp;&nbsp;&nbsp;#{link_to test.notice_number, notifier.preview_notice_kind_path(test), target: '_blank'}")
    end
  end

  # Formats a number into a 9-digit US Social Security Number string (nnn-nn-nnnn)
  def number_to_ssn(number)
    return unless number
    delimiter = "-"
    number.to_s.gsub!(/(\d{0,3})(\d{2})(\d{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
  end

  # Formats a number into a US Social Security Number string (nnn-nn-nnnn), hiding all but last 4 digits
  def number_to_obscured_ssn(number)
    return unless number
    number_to_ssn(number)
    if EnrollRegistry.feature_enabled?(:mask_ssn_ui_fields)
      '●●●●●●●●●'
    else
      number.to_s.gsub!(/\w{3}-\w{2}/, '***-**')
    end
  end

  def organize_ssn_params(form_object, family_member_id = nil)
    return unless form_object.ssn

    presenter = ::Presenters::SsnFormPresenter.new(form_object, family_member_id)
    presenter.sanitize_ssn_params
  end

  # Formats a number into a nine-digit US Federal Entity Identification Number string (nn-nnnnnnn)
  def number_to_fein(number)
    return unless number
    delimiter = "-"
    number.to_s.gsub!(/(\d{0,2})(\d{7})$/,"\\1#{delimiter}\\2")
  end

  # Formats a number into a nine-digit US Federal Entity Identification Number string (nn-nnnnnn), hiding all but last 4 digits
  def number_to_obscured_fein(number)
    return unless number
    number[0,5] = "**-***"
    number
  end

  # Formats a string into HTML, concatenating it with a person glyph
  def prepend_glyph_to_name(name)
    content_tag(:span, raw("&nbsp;"), class: "glyphicon glyphicon-user") + name
  end

  # Formats a string into HTML, concatenating it with a male glyph
  def prepend_male_glyph_to_name(name)
    content_tag(:i, class: "fa fa-male") + name
  end

  # Formats a string into HTML, concatenating it with a female glyph
  def prepend_female_glyph_to_name(name)
    content_tag(:i, raw("&nbsp;"), class: "fa fa-female") + name
  end

  # Formats a string into HTML, concatenating it with a child glyph
  def prepend_child_glyph_to_name(name)
    content_tag(:i, raw("&nbsp;"), class: "fa fa-child") + name
  end

  # Formats a Font Awesome icon in HTML
  def prepend_fa_icon(fa_icon, str)
    content_tag(:i, raw("&nbsp;"), class: "fa fa-#{fa_icon}") + str
  end

  def active_menu_item(label, path, controller = nil)
    li_start = (params[:controller] == controller.to_s) ? "<li class=\"active\">" : "<li>"
    "#{li_start}#{link_to(label, path)}</li>"
  end

  def active_dropdown_classes(*args)
    args.map(&:to_s).include?(params[:controller].to_s) ? "dropdown active" : "dropdown"
  end

    # rubocop:disable Naming/MethodParameterName
  def link_to_add_fields(name, f, association, classes = '')
  # rubocop:enable Naming/MethodParameterName
    new_object = f.object.send(association).klass.new
    id = new_object.object_id

    # TODO: add ability to build nested attributes dynamically
    if f.object.send(association).klass == OfficeLocation
      new_object.build_address
      new_object.build_phone
    end

    if f.object.send(association).klass == BenefitGroup
      new_object.build_relationship_benefits
      new_object.build_composite_tier_contributions
      new_object.build_dental_relationship_benefits
    end


    fields = f.fields_for(association, new_object, fieldset: false, child_index: id) do |builder|
      render("shared/#{association.to_s.singularize}_fields", f: builder)
    end
    link_to(content_tag(:span, raw("&nbsp;"), class: 'fui-plus-circle') + name,
            '#', class: "add_fields #{classes}", data: {id: id, fields: fields.gsub("\n", "")})
  end

  def render_flash(use_bs4: false)
    rendered = []
    flash.each do |type, messages|
      next if invalid_flash_messages?(messages)

      if messages.respond_to?(:each)
        messages.each do |m|
          rendered << get_flash(use_bs4, type, m) if m.present?
        end
      else
        rendered << get_flash(use_bs4, type, messages)
      end
    end
    sanitize_html(rendered.join)
  end

  def get_flash(use_bs4, type, msg)
    type = use_bs4 ? get_flash_type(type) : type
    if is_announcement?(msg)
      render(:partial => 'layouts/announcement_flash', :locals => {:type => type, :message => msg[:announcement]})
    else
      render(:partial => 'layouts/flash', :locals => {:type => type, :message => msg})
    end
  end

  def invalid_flash_messages?(messages)
    return true if messages.blank?
    return true if messages.respond_to?(:include?) && messages.include?("nil is not a symbol nor a string")

    # catch-all for boolean-type messages
    return true unless messages.is_a?(String) || messages.is_a?(Array)
    false
  end

  def get_flash_type(type)
    case type
    when "notice"
      "info"
    when "warning", "message"
      "warning"
    when "success"
      "success"
    else
      "error"
    end
  end

  def is_announcement?(item)
    item.respond_to?(:keys) && item[:is_announcement]
  end

  def show_table_notice(notice)
    sanitize_html(render(plain: notice)) if notice.present? && notice != flash[:notice]
  end

  def dd_value(val)
    val.blank? ? "&nbsp;" : val
  end

  def sortable(column, title = nil)
    fui = params[:direction] == "desc" ? "down" : "up"
    title ||= column.titleize
    css_class = (column == sort_column) ? "fui-triangle-#{fui}-small" : nil
    direction = (column == params[:sort] && params[:direction] == "desc") ? "asc" : "desc"
    ((link_to title, params.merge(:sort => column, :direction => direction, :page => nil)) + content_tag(:sort, raw("&nbsp;"), class: css_class))
  end

  def extract_phone_number(phones, type)
    phone = phones.select{|phone| phone.kind == type}
    if phone.present?
      phone = phone.first
      phone = phone.area_code.present? ? "#{phone.area_code} #{phone.number}" : nil
    else
      phone = nil
    end
    phone
  end

# the following methods are used when we are embedding devise signin and signup pages in views other than devise.
  def resource_name
    :user
  end

  def resource
    @resource ||= User.new
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end

  def get_dependents(family, _person)
    members_list = []
    family_members = family.family_members
    family_members.each {|f| members_list << f.person } if family_members.present?
    members_list
  end

  def add_progress_class(element_number, step)
    if element_number < step
      'complete'
    elsif element_number == step
      'active'
    end
  end

  def user_full_name
    if signed_in?
      current_user.person.try(:full_name) ? current_user.person.full_name : current_user.oim_id
    end
  end

  def user_first_name_last_name_and_suffix
    if signed_in?
      current_user.person.try(:first_name_last_name_and_suffix) ? current_user.person.first_name_last_name_and_suffix : current_user.oim_id.downcase
    end
  end

  def retrieve_show_path(provider, message)
    return  benefit_sponsors.inboxes_message_path(provider, message_id: message.id) if provider.try(:broker_role)
    case provider.model_name.name
    when "Person"
      insured_inbox_path(provider, message_id: message.id)
    when "EmployerProfile"
      employers_inbox_path(provider, message_id: message.id)
    when "BrokerAgencyProfile"
      benefit_sponsors.inboxes_message_path(provider, message_id: message.id)
    when "GeneralAgencyProfile"
      general_agencies_inbox_path(provider, message_id: message.id)
    end
  end

  def retrieve_inbox_path(provider, folder: 'inbox')
    if provider.try(:broker_role)
      broker_agency_mailbox =  benefit_sponsors.inbox_profiles_broker_agencies_broker_agency_profile_path(id: provider.id.to_s, folder: folder)
      return broker_agency_mailbox
    end

    case provider.model_name.name
    when "EmployerProfile"
      inbox_employers_employer_profiles_path(id: provider.id, folder: folder)
    when "BrokerAgencyProfile"
      benefit_sponsors.inbox_profiles_broker_agencies_broker_agency_profile_path(id: provider.id.to_s, folder: folder)
    when "Person"
      inbox_insured_families_path(profile_id: provider.id, folder: folder)
    when "GeneralAgencyProfile"
      inbox_general_agencies_profiles_path(profile_id: provider.id, folder: folder)
    end
  end

  def get_header_text(controller_name)
    portal_display_name(controller_name)
  end

  def can_register_new_account
    # Do this once we have invites working:
    # !params[:invitation_id].blank?
    true
  end

  def override_backlink
    link = ''
    if current_user.try(:has_hbx_staff_role?)
      link = link_to 'HBX Portal', exchanges_hbx_profile_path(id: 1)
    elsif current_user.try(:has_broker_agency_staff_role?)
      link = link_to 'Broker Agency Portal',broker_agencies_profile_path(id: current_user.person.broker_role.broker_agency_profile_id)
    end
    link
  end

  def carrier_logo(plan)
    if plan.extract_value.class.to_s == "Plan"
      return "" unless plan.carrier_profile.legal_name.extract_value.present?
      issuer_hios_id = plan.hios_id[0..4].extract_value
      Settings.aca.carrier_hios_logo_variant[issuer_hios_id] || plan.carrier_profile.legal_name.extract_value
    else
      return '' if plan.extract_value.issuer_profile.legal_name.nil?

      issuer_hios_id = plan.hios_id[0..4].extract_value
      Settings.aca.carrier_hios_logo_variant[issuer_hios_id] || plan.issuer_profile.legal_name.extract_value
    end
  end

  def display_carrier_logo(plan, options = {:width => 50})
    carrier_name = carrier_logo(plan)
    image_tag("logo/carrier/#{carrier_name.parameterize.underscore}.jpg", width: options[:width], alt: "#{carrier_name} logo") # Displays carrier logo (Delta Dental => delta_dental.jpg)
  end

  def digest_logos
    carrier_logo_hash = Hash.new(carriers: {})
    carriers = ::BenefitSponsors::Organizations::Organization.issuer_profiles
    carriers.each do |car|
      if Rails.env == "production"
        image = "logo/carrier/#{car.legal_name.parameterize.underscore}.jpg"
        digest_image = "/assets/#{::Sprockets::Railtie.build_environment(Rails.application).find_asset(image)&.digest_path}"
        carrier_logo_hash[car.legal_name] = digest_image
      else
        image = "/assets/logo/carrier/#{car.legal_name.parameterize.underscore}.jpg"
        carrier_logo_hash[car.legal_name] = image
      end
    end
    carrier_logo_hash
  end

  def display_carrier_pdf_logo(plan, options = {:width => 50})
    carrier_name = carrier_logo(plan)
    image_tag(wicked_pdf_asset_base64("logo/carrier/#{carrier_name.parameterize.underscore}.jpg"), width: options[:width]) # Displays carrier logo (Delta Dental => delta_dental.jpg)
  end

  def dob_in_words(age, dob)
    return age if age > 0
    time_ago_in_words(dob)
  end

  def date_col_name_for_broker_roaster
    if controller_name == 'applicants'
      case @status
      when 'active'
        'Accepted Date'
      when 'broker_agency_terminated'
        'Terminated Date'
      when 'broker_agency_declined'
        'Declined Date'
      end
    else
      case @status
      when 'applicant'
        'Submitted Date'
      when 'certified'
        'Certified Date'
      when 'decertified'
        'Decertified Date'
      when 'denied'
        'Denied Date'
      when 'extended'
        'Extended Date'
      end
    end
  end

  def relationship_options(dependent, referer)
    relationships = if referer.include?("consumer_role_id") || @person.try(:is_consumer_role_active?)
                      BenefitEligibilityElementGroup::Relationships_UI - ["self"]
                    else
                      PersonRelationship::Relationships_UI
                    end

    options_for_select(relationships.map{|r| [display_relationship(r.to_s), r.to_s] }, selected: dependent.try(:relationship))
  end

  def display_relationship(relationship)
    relationship_mapping = {
      l10n("insured.domestic_partner_key") => l10n("insured.domestic_partner_value"),
      l10n("insured.parents_partner_key") => l10n("insured.parents_partner_value")
    }

    relationship_mapping[relationship].try(:humanize) || relationship.try(:humanize)
  end

  def enrollment_progress_bar(plan_year, p_min, options = {:minimum => true})
    progress_bar_width = 0
    progress_bar_class = ''
    return if plan_year.nil?
    return if plan_year.employer_profile.census_employees.active.count > 200

    eligible = plan_year.eligible_to_enroll_count
    enrolled = plan_year.total_enrolled_count
    non_owner = plan_year.non_business_owner_enrolled.count
    covered = plan_year.progressbar_covered_count
    waived = plan_year.waived_count
    p_min = 0 if p_min.nil?

    unless eligible.zero?
      condition = enrolled >= p_min && non_owner > 0
      condition = false if covered == 0 && waived > 0
      progress_bar_class = condition ? 'progress-bar-success' : 'progress-bar-danger'
      progress_bar_width = (enrolled * 100) / eligible
    end

    content_tag(:div, class: 'progress-wrapper employer-dummy') do
      content_tag(:div, class: 'progress') do
        concat(content_tag(:div, class: "progress-bar #{progress_bar_class} progress-bar-striped", style: "width: #{progress_bar_width}%;", role: 'progressbar', aria: {valuenow: enrolled.to_s, valuemin: "0", valuemax: eligible.to_s},
                                 data: {value: enrolled.to_s}) do
                 concat content_tag(:span, '', class: 'sr-only')
               end)

        concat content_tag(:small, enrolled, class: 'progress-current', style: "left: #{progress_bar_width - 2}%;") if eligible > 1

        if eligible >= 2 && plan_year.employee_participation_ratio_minimum != 0
          eligible_text = (options[:minimum] == false) ? "#{p_min}<br>(Minimum)" : "<i class='fa fa-circle manual' data-toggle='tooltip' title='Minimum Requirement' aria-hidden='true'></i>"
          concat content_tag(:p, sanitize_html(eligible_text), class: 'divider-progress', data: {value: p_min.to_s})
        end

        concat(content_tag(:div, class: 'progress-val') do
          concat content_tag(:strong, '0', class: 'pull-left') if options[:minimum] == false
          concat content_tag(:strong, (options[:minimum] == false) ? eligible : '', data: {value: eligible.to_s}, class: 'pull-right')
        end)
      end
    end
  end

  def is_readonly(object)
    return false if current_user.roles.include?("hbx_staff") # can edit, employer census roster
    return true if object.try(:linked?)  # cannot edit, employer census roster
    !(object.new_record? or object.try(:eligible?)) # employer census roster
  end

  def may_update_census_employee?(census_employee)
    if current_user.roles.include?("hbx_staff") || census_employee.new_record? || census_employee.is_eligible?
      true
    else
      false
    end
  end

  def calculate_participation_minimum
    if @current_plan_year.present?
      if @current_plan_year.eligible_to_enroll_count == 0
        0
      else
        (@current_plan_year.eligible_to_enroll_count * @current_plan_year.employee_participation_ratio_minimum).ceil
      end
    end
  end

  def notice_eligible_enrolles(notice)
    notice.enrollments.inject([]) do |enrollees, enrollment|
      enrollees += enrollment.enrollees
    end.uniq
  end

  def show_oop_pdf_link(aasm_state)
    return false if aasm_state.blank?

    BenefitSponsors::BenefitApplications::BenefitApplication::SUBMITTED_STATES.include?(aasm_state.to_sym)
  end

  def calculate_age_by_dob(dob)
    now = TimeKeeper.date_of_record
    now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
  end

  def is_under_open_enrollment?
    HbxProfile.current_hbx.present? ? HbxProfile.current_hbx.under_open_enrollment? : nil
  end

  def ivl_enrollment_effective_date
    HbxProfile.current_hbx.try(:benefit_sponsorship).try(:earliest_effective_date)
  end

  def is_shop_market_enabled?
    EnrollRegistry.feature_enabled?(:aca_shop_market)
  end

  def is_fehb_market_enabled?
    EnrollRegistry.feature_enabled?(:fehb_market)
  end

  def is_individual_market_enabled?
    EnrollRegistry.feature_enabled?(:aca_individual_market)
  end

  def is_shop_and_individual_market_enabled?
    EnrollRegistry.feature_enabled?(:aca_shop_market) && EnrollRegistry.feature_enabled?(:aca_individual_market)
  end

  def is_shop_or_fehb_market_enabled?
    EnrollRegistry.feature_enabled?(:aca_shop_market) || EnrollRegistry.feature_enabled?(:fehb_market)
  end

  def parse_ethnicity(value)
    return "" unless value.present?
    value = value.select(&:present?)  if value.present?
    value.present? ? value.join(", ") : ""
  end

  # rubocop:disable Style/StringConcatenation
  def incarceration_cannot_purchase(family_member)
    pronoun = family_member.try(:gender) == 'male' ? ' he ' : ' she '
    name = family_member.try(:first_name) || ''
    "Since " + name + " is currently incarcerated," + pronoun + "is not eligible to purchase a plan on #{EnrollRegistry[:enroll_app].setting(:short_name).item}.<br/> Other family members may still be eligible to enroll."
  end
  # rubocop:enable Style/StringConcatenation

  def purchase_or_confirm
    'Confirm'
  end

  def qualify_qle_notice
    content_tag(:span) do
      concat "In order to purchase benefit coverage, you must be in either an Open Enrollment or Special Enrollment period. "
      concat link_to("Click here", find_sep_insured_families_path)
      concat " to see if you qualify for a Special Enrollment period"
    end
  end

  def trigger_notice_observer(recipient, event_object, notice_event, params = {})
    observer = BenefitSponsors::Observers::NoticeObserver.new
    observer.deliver(recipient: recipient, event_object: event_object, notice_event: notice_event, notice_params: params)
  end

  def disable_purchase?(disabled, hbx_enrollment, options = {})
    disabled || !hbx_enrollment.can_select_coverage?(qle: options[:qle])
  end

  def get_key_and_bucket(uri)
    splits = uri.split('#')
    key = splits.last
    bucket = splits.first.split(':').last
    [key, bucket]
  end

  def env_bucket_name(bucket_name)
    aws_env = ENV['AWS_ENV'] || "qa"
    subdomain = EnrollRegistry[:enroll_app].setting(:subdomain).item
    "#{subdomain}-enroll-#{bucket_name}-#{aws_env}"
  end

  def display_dental_metal_level(plan)
    if plan.instance_of?(::Plan) || (plan.is_a?(Maybe) && plan.extract_value.class.to_s == 'Plan')
      return plan.metal_level.to_s.titleize if plan.coverage_kind.to_s == 'health'

      (plan.active_year == 2015 ? plan.metal_level : plan.dental_level).try(:to_s).try(:titleize) || ""
    else
      return plan.metal_level_kind.to_s.titleize if plan.kind.to_s == 'health'

      (plan.active_year == 2015 ? plan.metal_level_kind : plan.dental_level).try(:to_s).try(:titleize) || ""
    end
  end

  def ivl_hsa_status(plan_hsa_status, plan)
    return unless plan_hsa_status.present?
    (plan_hsa_status[plan.id.to_s]) if plan.benefit_market_kind == :aca_individual
  end

  def osse_status(plan)
    plan.is_hc4cc_plan ? "Yes" : "No"
  end

  def products_count(products)
    return 0 unless products

    products.count
  end

  def make_binder_checkbox_disabled(employer)
    eligibility_criteria(employer)
    (@participation_count == 0 && @non_owner_participation_rule == true) ? false : true
  end

  def favorite_class(broker_role, general_agency_profile)
    return "" if broker_role.blank?

    if broker_role.included_in_favorite_general_agencies?(general_agency_profile.id)
      "glyphicon-star"
    else
      "glyphicon-star-empty"
    end
  end

  def show_default_ga?(general_agency_profile, broker_agency_profile)
    return false if general_agency_profile.blank? || broker_agency_profile.blank?
    broker_agency_profile.default_general_agency_profile == general_agency_profile
  end

  def asset_data_base64(path)
    asset = ::Sprockets::Railtie.build_environment(Rails.application).find_asset(path)
    throw "Could not find asset '#{path}'" if asset.nil?
    base64 = Base64.encode64(asset.to_s).gsub(/\s+/, "")
    "data:#{asset.content_type};base64,#{Rack::Utils.escape(base64)}"
  end

  def find_plan_name(hbx_id)
    HbxEnrollment.where(id: hbx_id).first.try(:product).try(:name)
  end

  def has_new_hire_enrollment_period?(census_employee)
    census_employee.new_hire_enrollment_period.present?
  end

  def eligibility_criteria(employer)
    return unless employer.respond_to?(:show_plan_year)
    show_plan_year = employer.show_plan_year
    if show_plan_year.present?
      participation_rule_text = participation_rule_for_plan_year(show_plan_year)
      non_owner_participation_rule_text = non_owner_participation_rule_for_plan_year(show_plan_year)
      text = (@participation_count == 0 && @non_owner_participation_rule == true ? "Yes" : "No")
      # eligibility_text = sanitize_html("Criteria Met : #{text}" + "<br>" + participation_rule_text + "<br>" + non_owner_participation_rule_text)
      if text == "Yes"
        "Eligible"
      else
        "Ineligible"
      end
    else
      "Ineligible"
    end
  end

  def participation_rule_for_plan_year(plan_year)
    @participation_count = plan_year.additional_required_participants_count

    if @participation_count == 0
      "1. 2/3 Rule Met? : Yes"
    else
      "1. 2/3 Rule Met? : No (#{@participation_count} more required)"
    end
  end

  def eligibility_criteria_for_export(employer)
    if employer.show_plan_year.present?
      @participation_count == 0 && @non_owner_participation_rule == true ? "Eligible" : "Ineligible"
    else
      "Ineligible"
    end
  end

  def participation_rule(employer)
    participation_rule_for_plan_year(employer.show_plan_year)
  end

  def non_owner_participation_rule_for_plan_year(plan_year)
    # fix me compare with total enrollments
    # fix me once new model enrollment and benefit group assignments got fixed
    @non_owner_participation_rule = plan_year.assigned_census_employees_without_owner.present?
    if @non_owner_participation_rule == true
      "2. Non-Owner exists on the roster for the employer"
    else
      "2. You have 0 non-owner employees on your roster"
    end
  end

  def non_owner_participation_rule(employer)
    # fix me compare with total enrollments
    # fix me once new model enrollment and benefit group assignments got fixed
    non_owner_participation_rule_for_plan_year(employer.show_plan_year)
  end

  def is_new_paper_application?(current_user, app_type)
    app_type = app_type&.downcase
    current_user.has_hbx_staff_role? && app_type == "paper"
  end

  def is_new_in_person_application?(current_user, app_type)
    app_type = app_type&.humanize&.downcase
    current_user.has_hbx_staff_role? && app_type == "in person"
  end

  def load_captcha_widget?
    !Rails.env.test?
  end

  def previous_year
    TimeKeeper.date_of_record.prev_year.year
  end

  def resident_application_enabled?
    if Settings.aca.individual_market.dc_resident_application
      policy(:family).hbx_super_admin_visible?
    else
      false
    end
  end

  def can_show_covid_message_on_sep_carousel?(person)
    return false unless sep_carousel_message_enabled?
    return false unless person.present?
    return true if person.consumer_role.present? || person.resident_role.present?
    person&.active_employee_roles&.any?{ |employee_role| employee_role.market_kind == 'shop'}
  end

  def transition_family_members_link_type(row, allow)
    if Settings.aca.individual_market.transition_family_members_link
      allow && row.primary_applicant.person.has_consumer_or_resident_role? ? 'ajax' : 'disabled'
    else
      "disabled"
    end
  end

  def convert_to_bool(val)
    return true if val == true || val == 1 || val =~ (/^(true|t|yes|y|1)$/i)
    return false if val == false || val == 0 || val =~ (/^(false|f|no|n|0)$/i)
    raise(ArgumentError, "invalid value for Boolean: \"#{val}\"")
  end

  def checkbook_integration_enabled?
    ::EnrollRegistry[:checkbook_integration].enabled?
  end

  def exchange_icon_path(icon)
    site_key = EnrollRegistry[:enroll_app].setting(:site_key).item
    "icons/#{site_key}-#{icon}"
  end

  def benefit_application_summarized_state(benefit_application)
    return if benefit_application.nil?
    aasm_map = {
      :draft => :draft,
      :enrollment_open => :enrolling,
      :enrollment_eligible => :enrolled,
      :binder_paid => :enrolled,
      :approved => :published,
      :pending => :publish_pending
    }

    renewing = benefit_application.predecessor_id.present? && benefit_application.reinstated_id.blank? && [:active, :terminated, :termination_pending].exclude?(benefit_application.aasm_state) ? "Renewing" : ""
    summary_text = aasm_map[benefit_application.aasm_state] || benefit_application.aasm_state
    summary_text = "#{renewing} #{summary_text.to_s.humanize.titleize}"
    summary_text.strip
  end

  def json_for_plan_shopping_member_groups(member_groups)
    member_groups.map do |member_group|
      member_group_hash = JSON.parse(member_group.group_enrollment.to_json)
      member_group_hash['product'].merge!(
        "issuer_name" => member_group.group_enrollment.product.issuer_profile.legal_name,
        "product_type" => member_group.group_enrollment.product.product_type
      )
      member_group_hash
    end.to_json
  end

  def can_access_pay_now_button
    hbx_staff_role = current_user.person.hbx_staff_role
    return true if hbx_staff_role.blank?

    hbx_staff_role.permission.can_access_pay_now
  end

  def float_fix(float_number)
    BigDecimal(float_number.to_s).round(8).to_f
  end

  def round_down_float_two_decimals(float_number)
    BigDecimal(float_number.to_s).round(8).round(2, BigDecimal::ROUND_DOWN).to_f
  end

  def external_application_configured?(application_name)
    external_app = ::ExternalApplications::ApplicationProfile.find_by_application_name(application_name)
    return false unless external_app
    return false unless external_app.is_authorized_for?(current_user)
    !external_app.url.blank?
  end

  def jwt_for_external_application
    current_token = WhitelistedJwt.newest
    return current_token.token if current_token
    current_user.generate_jwt(warden.config[:default_scope], nil)
  end

  def csr_percentage_options_for_select
    EligibilityDetermination::CSR_PERCENT_VALUES.inject([]) do |csr_options, csr|
      ui_display = csr == '-1' ? 'limited' : csr
      csr_options << [ui_display, csr]
    end
  end

  def show_component(url)
    if url.split('/')[2] == "consumer_role" || url.split('/')[1] == "insured" && url.split('/')[2] == "interactive_identity_verifications" || url.split('/')[1] == "financial_assistance" && url.split('/')[2] == "applications" || url.split('/')[1] == "insured" && url.split('/')[2] == "family_members" || url.include?("family_relationships")
      false
    else
      true
    end
  end

  def display_my_broker?(person, employee_role)
    employee_role ||= person.active_employee_roles.first
    (person.has_active_employee_role? && employee_role.employer_profile.broker_agency_profile.present?) || (person.has_active_consumer_role? && person.primary_family.current_broker_agency.present?)
  end

  def display_family_members(family_members, primary_person)
    return family_members if family_members.present?
    primary_person&.primary_family&.active_family_members || []
  end

  def display_broker_info_for_consumer
    if ::EnrollRegistry.feature_enabled?(:disable_family_link_in_broker_agency)
      current_user.has_hbx_staff_role? || !::EnrollRegistry[:disable_family_link_in_broker_agency].setting(:enable_after_time_period).item.cover?(TimeKeeper.date_of_record)
    else
      true
    end
  end

  def display_childcare_program_options(person)
    person.has_active_consumer_role? || person.has_active_resident_role?
  end

  def registration_recaptcha_enabled?(profile_type)
    case profile_type
    when "broker_agency"
      EnrollRegistry.feature_enabled?(:registration_broker_recaptcha)
    when "general_agency"
      EnrollRegistry.feature_enabled?(:registration_ga_recaptcha)
    when "user_account"
      EnrollRegistry.feature_enabled?(:registration_user_account_recaptcha)
    when "benefit_sponsor"
      EnrollRegistry.feature_enabled?(:registration_sponsor_recaptcha)
    else
      false
    end
  end

  def forgot_password_recaptcha_enabled?
    EnrollRegistry.feature_enabled?(:forgot_password_recaptcha)
  end

  def plan_childcare_subsidy_eligible(plan)
    plan.is_eligible_for_osse_grant? && plan.is_hc4cc_plan
  end

  def current_osse_status_for_role(role)
    date = TimeKeeper.date_of_record
    active_eligibility = role.active_eligibility_on(date)

    if active_eligibility.present?
      "Active for (#{date.year})"
    else
      "Not Active for (#{date.year})"
    end
  end

  def individual_osse_eligibility_years_for_display
    ::BenefitCoveragePeriod.osse_eligibility_years_for_display.sort.reverse
  end

  # => START: Broker Role Consumer Role(Dual Roles) Enhancement.

  # Method: eligible_to_redirect_to_home_page?
  #
  # This method checks if a user is eligible to be redirected to the family home page.
  #
  # @param [User] user The user to check for eligibility.
  #
  # @return [Boolean]
  #   returns true if the user has an employee role
  #   returns true if the 'broker_role_consumer_enhancement' feature is not enabled
  #   returns true if the user has a consumer role and their identity is verified.
  #   Otherwise, it returns false.
  #
  # @example
  #   eligible_to_redirect_to_home_page?(user) #=> true/false
  def eligible_to_redirect_to_home_page?(user)
    return true if user.has_employee_role?
    return true unless EnrollRegistry.feature_enabled?(:broker_role_consumer_enhancement)

    user.has_consumer_role? && RemoteIdentityProofingStatus.is_complete_for_person?(user.person)
  end

  # @method insured_role_exists?(user)
  # Checks if the user has an insured role.
  #
  # @param [User] user The user to check for insured roles.
  #
  # @return [Boolean]
  #   returns true if the user has an employee role.
  #   returns true if the user has a consumer role and the 'broker_role_consumer_enhancement' feature is enabled.
  #   returns true if the user has a consumer role and their identity is verified when the 'broker_role_consumer_enhancement' feature is disabled enabled.
  #   Otherwise, it returns false.
  #
  # @example Check if a user has an insured role
  #   insured_role_exists?(user) #=> true/false
  def insured_role_exists?(user)
    return true if user.has_employee_role?

    if EnrollRegistry.feature_enabled?(:broker_role_consumer_enhancement)
      user.has_consumer_role?
    else
      user.has_consumer_role? && RemoteIdentityProofingStatus.is_complete_for_person?(user.person)
    end
  end

  # => END: Broker Role Consumer Role(Dual Roles) Enhancement

  # @method ridp_step_2_disabled
  # Used to determine if the continue button should be disabled on ridp pages.
  def ridp_step_2_disabled(person, application_verified, identity_verified)
    return !identity_verified unless current_user.has_hbx_staff_role? && (person.primary_family.application_type == "Phone" || person.primary_family.application_type == "Paper")
    (application_verified || identity_verified) ? false : true
  end

  def ridp_modal_options
    {
      :driver_license => "Driver's License issued by state or territory",
      :school_id => "School identification card",
      :military_id => "U.S. military card or draft record",
      :passport => "Identification card issued by the federal, state or local government, including a U.S. Passport",
      :military_dependent => "Military dependent's identification card",
      :native_american => "Native American tribal document",
      :coast_guard => "U.S. Coast Guard Merchant Mariner card"
    }
  end

  def imm_docs_requried_class
    FinancialAssistanceRegistry.feature_enabled?(:optional_document_fields) ? "" : "required"
  end

  # HTML patterns for validation are case sensative. In order to make them case insensative, we need to convert them to case insensative patterns.
  def match_char_pattern(string)
    string.chars.map{  |char| "[#{char.upcase}#{char.downcase}]" }.join
  end

  def date_field_value(date = nil)
    date = Date.current if date.nil? || date.to_s == "0"
    date.strftime("%Y-%m-%d")
  end
end

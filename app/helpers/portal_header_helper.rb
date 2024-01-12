# frozen_string_literal: true

# Here is a comment
module PortalHeaderHelper
  include L10nHelper
  include ApplicationHelper

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def portal_display_name(controller)
    if current_user.nil?
      "<a class='portal'>#{l10n('welcome.index.welcome_to_site_header')}</a>".html_safe
    elsif current_user.try(:has_hbx_staff_role?)
      link_to "#{image_tag 'icons/icon-exchange-admin.png'} &nbsp; I'm an Admin".html_safe, main_app.exchanges_hbx_profiles_root_path, class: "portal"
    elsif display_i_am_broker_for_consumer?(current_user.person) && controller_path.exclude?('general_agencies')
      link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Broker".html_safe, get_broker_profile_path, class: "portal"
    elsif current_user.try(:person).try(:csr_role) || current_user.try(:person).try(:assister_role)
      link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Trained Expert".html_safe, main_app.home_exchanges_agents_path, class: "portal"
    elsif current_user.person&.active_employee_roles&.any?
      if controller_path.include?('broker_agencies')
        link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Broker".html_safe, get_broker_profile_path, class: "portal"
      elsif controller_path.include?('general_agencies')
        link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a General Agency".html_safe,
                benefit_sponsors.profiles_general_agencies_general_agency_profile_path(id: current_user.person.general_agency_staff_roles.first.benefit_sponsors_general_agency_profile_id), class: "portal"
      elsif controller == 'employer_profiles' || controller_path.include?('employers')
        #current user has both broker_agency staff role and employee role but not employer_staff_roles
        if current_user.person.active_employer_staff_roles.present?
          employer_profile_path = benefit_sponsors.profiles_employers_employer_profile_path(id: current_user.person.active_employer_staff_roles.first.benefit_sponsor_employer_profile_id, :tab => 'home')
          link_to "#{image_tag 'icons/icon-business-owner.png'} &nbsp; I'm an Employer".html_safe, employer_profile_path, class: "portal"
        elsif current_user.try(:has_broker_agency_staff_role?)
          link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Broker".html_safe, get_broker_profile_path, class: "portal"
        end
      else
        link_to "#{image_tag exchange_icon_path('icon-individual.png')} &nbsp; I'm an Employee".html_safe, main_app.family_account_path, class: "portal"
      end
    elsif (controller_path.include?("insured") && current_user.try(:has_consumer_role?)) ||
          (EnrollRegistry.feature_enabled?(:financial_assistance) && controller_path.include?("financial_assistance") && current_user.try(:has_consumer_role?))
      if current_user.identity_verified_date.present?
        link_to "#{image_tag 'icons/icon-family.png'} &nbsp; Individual and Family".html_safe, main_app.family_account_path, class: "portal"
      else
        "<a class='portal'>#{image_tag 'icons/icon-family.png'} &nbsp; Individual and Family</a>".html_safe
      end
    # rubocop:disable Lint/DuplicateBranch
    elsif current_user.try(:has_broker_agency_staff_role?) && controller_path.exclude?('general_agencies') && controller_path.exclude?('employers')
      link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a Broker".html_safe, get_broker_profile_path, class: "portal"
    # rubocop:enable Lint/DuplicateBranch
    elsif current_user.try(:has_general_agency_staff_role?)
      if current_user.try(:has_employer_staff_role?) && controller_path.include?('employers')
        link_to "#{image_tag 'icons/icon-business-owner.png'} &nbsp; I'm an Employer".html_safe,
                benefit_sponsors.profiles_employers_employer_profile_path(id: current_user.person.active_employer_staff_roles.first.benefit_sponsor_employer_profile_id, :tab => 'home'), class: "portal"
      else
        link_to "#{image_tag 'icons/icon-expert.png'} &nbsp; I'm a General Agency".html_safe,
                benefit_sponsors.profiles_general_agencies_general_agency_profile_path(id: current_user.person.active_general_agency_staff_roles.first.benefit_sponsors_general_agency_profile_id), class: "portal"
      end
    elsif current_user.try(:has_employer_staff_role?)
      link_to "#{image_tag 'icons/icon-business-owner.png'} &nbsp; I'm an Employer".html_safe,
              benefit_sponsors.profiles_employers_employer_profile_path(id: current_user.person.active_employer_staff_roles.first.benefit_sponsor_employer_profile_id, :tab => 'home'), class: "portal"
    else
      "<a class='portal'>#{l10n('welcome.index.byline', welcome_text: EnrollRegistry[:enroll_app].setting(:header_message).item.to_s)}</a>".html_safe
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # rubocop:disable Naming/AccessorMethodName
  def get_broker_profile_path
    @broker_role ||= current_user.person.broker_role
    broker_agency_profile = @broker_role&.broker_agency_profile
    #if class is from benefit sponsor
    class_string = broker_agency_profile.class.to_s.demodulize
    klass_name = ["BrokerAgencyProfile"].include?(class_string) ? class_string.constantize : nil

    if broker_agency_profile.is_a? BrokerAgencyProfile
      main_app.broker_agencies_profile_path(id: @broker_role.broker_agency_profile_id)
    elsif klass_name == BrokerAgencyProfile
      benefit_sponsors.profiles_broker_agencies_broker_agency_profile_path(id: @broker_role.benefit_sponsors_broker_agency_profile_id)
    end
  end
  # rubocop:enable Naming/AccessorMethodName

  # @method display_i_am_broker_for_consumer?(person)
  # Determines if the 'I am Broker' should be displayed for a given person with active Consumer Role.
  #
  # @param [Person] person The person for whom to check the broker status.
  #
  # @return [Boolean]
  #   When the feature ':broker_role_consumer_enhancement' is enabled and Active Consumer Role exists:
  #     Returns true if active broker role, active broker agency staff role, and both the active broker agency staff & active broker role have the same broker agency profile.
  #     else returns false.
  #   When the feature ':broker_role_consumer_enhancement' is disabled:
  #     Returns true if person has a broker role.
  #     else returns false.
  #
  # @example Check if 'I am Broker' should be displayed for a person with active Consumer Role
  #   display_i_am_broker_for_consumer?(person) #=> true/false
  def display_i_am_broker_for_consumer?(person)
    return if person.blank?

    if EnrollRegistry.feature_enabled?(:broker_role_consumer_enhancement) && person.has_active_consumer_role?
      broker_role = person.broker_role
      matching_basr = person.broker_agency_staff_roles.where(
        benefit_sponsors_broker_agency_profile_id: broker_role&.benefit_sponsors_broker_agency_profile_id
      ).first
      broker_role.present? && broker_role.active? && matching_basr.present? && matching_basr.active?
    else
      person.broker_role.present?
    end
  end
end

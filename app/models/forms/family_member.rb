module Forms
  class FamilyMember
    include ActiveModel::Model
    include ActiveModel::Validations
    include Config::AcaModelConcern

    attr_accessor :id, :family_id, :is_consumer_role, :is_resident_role, :vlp_document_id, :gender, :relationship, :is_tobacco_user, :tribe_codes,
                  :addresses, :is_homeless, :is_temporarily_out_of_state, :is_moving_to_state, :same_with_primary, :is_applying_coverage, :age_off_excluded, :immigration_doc_statuses,
                  :skip_consumer_role_callbacks, :skip_person_updated_event_callback
    attr_writer :family
    include ::Forms::PeopleNames
    include ::Forms::ConsumerFields
    include ::Forms::SsnField
    include ActionView::Helpers::TranslationHelper
    include L10nHelper
    RELATIONSHIPS = ::PersonRelationship::Relationships + ::BenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS
    #include ::Forms::DateOfBirthField
    #include Validations::USDate.on(:date_of_birth)

    def initialize(*attributes)
      @addresses = [Address.new(kind: 'home'), Address.new(kind: 'mailing')]
      @same_with_primary = "true"
      @is_applying_coverage = true
      super
    end

    validates_presence_of :first_name, :allow_blank => nil
    validates_presence_of :last_name, :allow_blank => nil
    validates_presence_of :gender, :allow_blank => nil
    validates_presence_of :family_id, :allow_blank => nil
    validates_presence_of :dob
    validates_inclusion_of :relationship, :in => RELATIONSHIPS.uniq, :allow_blank => nil, message: ""
    validate :relationship_validation
    validate :verify_unique_dependent
    validate :consumer_fields_validation
    validate :ssn_validation

    attr_reader :dob

    HUMANIZED_ATTRIBUTES = { relationship: "Select Relationship Type " }

    def self.human_attribute_name(attr, options={})
      HUMANIZED_ATTRIBUTES[attr.to_sym] || super
    end

    def consumer_fields_validation
      return true unless individual_market_is_enabled?
      if (@is_consumer_role.to_s == "true" && is_applying_coverage.to_s == "true")#only check this for consumer flow.
        if @us_citizen.nil?
          self.errors.add(:base, "Citizenship status is required")
        elsif @us_citizen == false && (@eligible_immigration_status.nil? && EnrollRegistry[:immigration_status_question_required].item)
          self.errors.add(:base, "Eligible immigration status is required")
        elsif @us_citizen == true && @naturalized_citizen.nil?
          self.errors.add(:base, "Naturalized citizen is required")
        end

        self.errors.add(:base, "native american / alaska native status is required") if @indian_tribe_member.nil?
        validate_tribe_details if @indian_tribe_member
      end

      return unless (@is_resident_role.to_s == "true" || @is_consumer_role.to_s == "true") && is_applying_coverage.to_s == "true" && @is_incarcerated.nil?
      self.errors.add(:base, "Incarceration status is required")
    end

    def validate_tribe_details
      if EnrollRegistry[:indian_alaskan_tribe_details].enabled?
        self.errors.add(:tribal_state, "is required when native american / alaska native is selected") unless tribal_state.present?
        validate_featured_tribes if FinancialAssistanceRegistry[:featured_tribes_selection].enabled?
        self.errors.add(:tribal_name, "is required when native american / alaska native is selected") if !tribal_name.present? && !FinancialAssistanceRegistry[:featured_tribes_selection].enabled?
        self.errors.add(:tribal_name, "cannot contain numbers") unless (tribal_name =~ /\d/).nil?
      else
        self.errors.add(:tribal_id, "is required when native american / alaska native is selected") unless tribal_id.present?
        self.errors.add(:tribal_id, "Tribal id must be 9 digits") if tribal_id.present? && !tribal_id.match("[0-9]{9}")
      end
    end

    def validate_featured_tribes
      if tribal_state == EnrollRegistry[:enroll_app].setting(:state_abbreviation).item
        self.errors.add(:tribal_name, "is required when native american / alaska native is selected") if tribe_codes.include?("OT") && !tribal_name.present?
        self.errors.add(:base, "At least one tribe must be selected") if tribe_codes.empty?
      else
        self.errors.add(:tribal_name, "is required when native american / alaska native is selected") unless tribal_name.present?
      end
    end

    def ssn_validation
      return unless is_applying_coverage?
      return true if is_applying_coverage == "false"
      return true unless individual_market_is_enabled?

      self.errors.add(:base, "SSN is required") if @ssn.blank? && @no_ssn == '0'
    end

    def is_applying_coverage?
      is_applying_coverage.to_s == "true"
    end

    def dob=(val)
      @dob = Date.strptime(val, "%Y-%m-%d") rescue nil
    end

    def consumer_role=(val)
      true
    end

    def save
      assign_citizen_status
      return false unless valid?
      existing_inactive_family_member = family.find_matching_inactive_member(self)
      if existing_inactive_family_member
        self.id = existing_inactive_family_member.id
        existing_inactive_family_member.reactivate!(self.relationship)
        return true if family.save && existing_inactive_family_member.save
      end
      existing_person = Person.match_existing_person(self)
      if existing_person
        family_member = family.relate_new_member(existing_person, self.relationship)
        if self.is_consumer_role == "true"
          family_member.family.build_consumer_role(family_member, {skip_consumer_role_callbacks: @skip_consumer_role_callbacks})
        elsif self.is_resident_role == "true"
          family_member.build_resident_role(family_member)
        end
        assign_person_address(existing_person)
        self.id = family_member.id
        # RE exception: Updating the path 'households.0.coverage_households' would create a conflict at 'households.0.coverage_households'
        # This will cover the use case of attempting to save a family member which has duplicate family members
        # with coverage household members, HBX enrollment members, etc.
        # will not allow the family member to be saved if thoses duplicate issues are for a current enrollment.
        duplicate_family_members = family.family_members.where(person_id: existing_person.id)
        duplicate_family_member_ids = duplicate_family_members.pluck(:id)
        if duplicate_family_members && family.duplicate_enr_members_or_tax_members_present?(duplicate_family_member_ids)
          Rails.logger.warn(
            "Cannot remove the duplicate members as they are present on enrollments/tax households." \
            " Issue occurs on person HBX_ID #{existing_person.hbx_id} from Family with ID #{family.id}."
          )
          return [false, l10n('insured.family_members.duplicate_error_message', action: "remove", contact_center_phone_number: EnrollRegistry[:enroll_app].settings(:contact_center_short_number).item)]
        else
          family.remove_duplicate_members(duplicate_family_member_ids)
          family.reload
        end
        return true if family_member.save && family.save
      end
      person = Person.new(extract_person_params)
      return false unless try_create_person(person)
      family_member = family.relate_new_member(person, self.relationship)
      if self.is_consumer_role == "true"

        # DO NOT change the order of the key value pairs
        additional_params = { skip_consumer_role_callbacks: @skip_consumer_role_callbacks }.merge(extract_consumer_role_params)

        family_member.family.build_consumer_role(family_member, additional_params)
      elsif self.is_resident_role == "true"
        family_member.family.build_resident_role(family_member)
      end
      assign_person_address(person)
      family.save_relevant_coverage_households
      family_member.save
      self.id = family_member.id
      return true if family.save
    end

    def try_create_person(person)
      person.save.tap do
        bubble_person_errors(person)
      end
    end

    def assign_person_address(person)
      if same_with_primary == 'true'
        primary_person = family.primary_family_member.person
        person.update(is_homeless: primary_person.is_homeless?, is_temporarily_out_of_state: primary_person.is_temporarily_out_of_state?)
        address = primary_person.home_address
        if address.present?
          person.home_address.try(:destroy)
          attrs = address.attributes.slice('address_1', 'address_2', 'address_3', 'county', 'country_name', 'kind', 'city', 'state', 'zip')
          person.addresses << ::Address.new(attrs)
          person.save
        end
      else
        home_address = person.home_address rescue nil
        mailing_address = person.has_mailing_address? ? person.mailing_address : nil

        addresses.each do |key, address|
          sanitized_address = sanitize_address(address)
          current_address = case sanitized_address["kind"]
                            when "home"
                              home_address
                            when "mailing"
                              mailing_address
                            else
                              next
                            end
          if sanitized_address["address_1"].blank? && sanitized_address["city"].blank?
            current_address.destroy if current_address.present?
            next
          end
          if current_address.present?
            current_address.update(sanitized_address)
            person.save! # to trigger address change events
          else
            person.addresses.create(sanitized_address)
          end
        end
      end
      true
    rescue => e
      false
    end

    def sanitize_address(address)
      if address.instance_of?(ActionController::Parameters)
        address.except("_destroy").permit(:address_1, :address_2, :city, :state, :zip, :kind, :county)
      else
        address.except("_destroy")
      end
    end

    def extract_consumer_role_params
      {
        :citizen_status => @citizen_status,
        :vlp_document_id => vlp_document_id,
        :is_applying_coverage => is_applying_coverage
      }
    end

    def extract_person_params
      {
        :first_name => first_name,
        :last_name => last_name,
        :middle_name => middle_name,
        :name_pfx => name_pfx,
        :name_sfx => name_sfx,
        :gender => gender,
        :dob => dob,
        :ssn => ssn,
        :no_ssn => no_ssn,
        :race => race,
        :ethnicity => ethnicity,
        :language_code => language_code,
        :is_incarcerated => is_incarcerated,
        :citizen_status => @citizen_status,
        :tribal_id => tribal_id,
        :tribal_state => tribal_state,
        :tribal_name => tribal_name,
        :tribe_codes => tribe_codes,
        :is_homeless => is_homeless,
        :is_temporarily_out_of_state => is_temporarily_out_of_state,
        :is_moving_to_state => is_moving_to_state,
        :age_off_excluded => age_off_excluded,
        :is_tobacco_user => is_tobacco_user
      }
    end

    def persisted?
      !id.blank?
    end

    def destroy!
      status, messages = family.remove_family_member(family_member.person)
      if status
        family.save
      else
        self.errors.add(:base, messages)
      end
    end

    def family
      @family ||= Family.find(family_id)
    end

    def self.find(family_member_id, action = nil)
      found_family_member = ::FamilyMember.find(family_member_id)
      has_same_address_with_primary = compare_address_with_primary(found_family_member)
      home_address = if has_same_address_with_primary
                       Address.new(kind: 'home')
                     else
                       found_family_member.try(:person).try(:home_address) || Address.new(kind: 'home')
                     end
      mailing_address = found_family_member.person.has_mailing_address? ? found_family_member.person.mailing_address : Address.new(kind: 'mailing')
      record = self.new({
        :id => family_member_id,
        :same_with_primary => has_same_address_with_primary.to_s,
        :is_homeless => has_same_address_with_primary ? '' : found_family_member.try(:person).try(:is_homeless),
        :is_temporarily_out_of_state => has_same_address_with_primary ? '' : found_family_member.try(:person).try(:is_temporarily_out_of_state),
        :addresses => [home_address, mailing_address]
      }.merge(member_params(found_family_member, action)))
    end

    def self.member_params(member, action)
      params = {:relationship => member.primary_relationship,
                :family => member.family,
                :family_id => member.family_id,
                :first_name => member.first_name,
                :last_name => member.last_name,
                :middle_name => member.middle_name,
                :name_pfx => member.name_pfx,
                :name_sfx => member.name_sfx,
                :dob => (member.dob.is_a?(Date) ? member.dob.try(:strftime, "%Y-%m-%d") : member.dob),
                :gender => member.gender,
                :ssn => member.ssn,
                :no_ssn => member.no_ssn,
                :race => member.race,
                :ethnicity => member.ethnicity,
                :language_code => member.language_code,
                :indian_tribe_member => indian_tribe_member_status(member),
                :tribal_id => member.tribal_id,
                :tribal_state => member.tribal_state,
                :tribal_name => member.tribal_name,
                :tribe_codes => member.tribe_codes,
                :age_off_excluded => member.try(:person).try(:age_off_excluded),
                :is_moving_to_state => member.try(:person).try(:is_moving_to_state),
                :is_tobacco_user => member&.person&.is_tobacco_user}

      consumer_fields = if action == "edit" && member.person.consumer_role.is_applying_coverage == false
                          { :citizen_status => nil,
                            :naturalized_citizen => nil,
                            :eligible_immigration_status => nil,
                            :is_incarcerated => nil}
                        else
                          {:citizen_status => member.citizen_status,
                           :naturalized_citizen => member.naturalized_citizen,
                           :eligible_immigration_status => member.eligible_immigration_status,
                           :is_incarcerated => member.is_incarcerated}
                        end

      params.merge!(consumer_fields)
      params
    end

    def self.indian_tribe_member_status(member)
      person = member&.person
      result = !(person.tribal_id.nil? || person.tribal_id.empty?)
      result = !(person.tribal_state.nil? || person.tribal_state.empty?) if EnrollRegistry[:indian_alaskan_tribe_details].enabled?

      result
    end

    def self.compare_address_with_primary(family_member)
      current = family_member.person
      primary = family_member.family.primary_family_member.person

      compare_keys = ["address_1", "address_2", "city", "state", "zip"]
        current.is_homeless? == primary.is_homeless? &&
        current.is_temporarily_out_of_state? == primary.is_temporarily_out_of_state? &&
        current.home_address.attributes.select{|k,v| compare_keys.include? k} == primary.home_address.attributes.select{|k,v| compare_keys.include? k}
    rescue
      false
    end

    def family_member
      @family_member = ::FamilyMember.find(id)
    end

    def assign_attributes(atts)
      atts.each_pair do |k, v|
        self.send("#{k}=".to_sym, v)
      end
    end

    def bubble_person_errors(person)
      self.errors.add(:ssn, person.errors[:ssn]) if person.errors.has_key?(:ssn)
    end

    def try_update_person(person)
      person&.consumer_role&.update_attributes(skip_consumer_role_callbacks: @skip_consumer_role_callbacks, :is_applying_coverage => is_applying_coverage)

      person.update_attributes(extract_person_params).tap do
        bubble_person_errors(person)
      end
    end

    def update_attributes(attr)
      assign_attributes(attr)
      assign_citizen_status
      return false unless valid?
      person = family_member.person
      person.skip_person_updated_event_callback = @skip_person_updated_event_callback
      assign_person_address(person)
      return false unless try_update_person(person)
      if attr["is_consumer_role"] == "true"
        family_member.family.build_consumer_role(family_member, {skip_consumer_role_callbacks: @skip_consumer_role_callbacks})
      elsif attr["is_resident_role"] == "true"
        family_member.family.build_resident_role(family_member)
      end
      family_member.update_relationship(relationship)
      family_member.save
    end

    def age_on(date)
      age = date.year - dob.year
      if date.month < dob.month || (date.month == dob.month && date.day < dob.day)
        age - 1
      else
        age
      end
    end

    # TODO: This may have to also be in the family member model someday. Or applicant model,
    # in the financial assistance engine. Who knows.
    def verify_unique_dependent
      # Only run on create
      return if self.persisted?
      return if family.blank? || family.family_members.blank?
      new_dependent = self
      # Don't use SSN in case there is no SSN
      potential_duplicate_present = family.family_members.active.any? do |family_member|
        family_member&.first_name == new_dependent.first_name &&
          family_member&.last_name == new_dependent.last_name &&
          family_member&.dob == new_dependent.dob
      end
      # Disabling rubocop because it seems like a guard clause changes behavior
      # rubocop:disable Style/GuardClause
      if potential_duplicate_present
        # Manage Family Page Redirect
        duplicate_message = l10n(
          'insured.family_members.duplicate_error_message',
          action: "add",
          contact_center_phone_number: EnrollRegistry[:enroll_app].settings(:contact_center_short_number).item
        )
        self.errors.add(:base, duplicate_message)
      end
      # rubocop:enable Style/GuardClause
    end

    def relationship_validation
      return if family.blank? || family.family_members.blank?

      relationships = Hash.new
      family.active_family_members.each{|fm| relationships[fm._id.to_s]=fm.relationship}
      relationships[self.id.to_s] = self.relationship
      if relationships.values.count{|rs| rs=='spouse' || rs=='life_partner'} > 1
        self.errors.add(:base, "can not have multiple spouse or life partner")
      end
    end
  end
end

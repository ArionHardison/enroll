class Person
  include Config::AcaModelConcern
  include Config::SiteModelConcern
  include Config::ContactCenterModelConcern
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  # include Mongoid::Versioning
  include Ssn
  include Mongoid::Attributes::Dynamic
  # include SponsoredBenefits::Concerns::Ssn
  # include SponsoredBenefits::Concerns::Dob

  include Notify
  include UnsetableSparseFields
  include FullStrippedNames
  include ::BenefitSponsors::Concerns::Observable
  include SponsoredBenefits::Concerns::Dob
  include LegacyVersioningRecords
  include CrmGateway::PersonConcern
  include L10nHelper
  include Eligibilities::Visitors::Visitable
  include EventSource::Command
  include GlobalID::Identification

  # verification history tracking
  include Mongoid::History::Trackable

  # transmittable subject
  include Transmittable::Subject

  include Orms::Mongoid::DomainModel

  # includes TimeHelper module for time related helper methods
  include TimeHelper

  track_history :on => [:first_name,
                        :middle_name,
                        :last_name,
                        :full_name,
                        :alternate_name,
                        :encrypted_ssn,
                        :dob,
                        :gender,
                        :is_incarcerated,
                        :is_disabled,
                        :ethnicity,
                        :race,
                        :tribal_id,
                        :tribal_state,
                        :tribal_name,
                        :no_dc_address,
                        :is_homeless,
                        :is_temporarily_out_of_state,
                        :is_active,
                        # There is suspicion that hbx_id is being updated for a Person. Ideally, hbx_id should not be updated for a Person record.
                        # By adding hbx_id to the track_history, we can track when the hbx_id is being updated to figure out the root cause.
                        :hbx_id,
                        :no_ssn],
                :modifier_field => :modifier,
                :modifier_field_optional => true,
                :version_field => :tracking_version,
                :track_create  => true,    # track document creation, default is false
                :track_update  => true,    # track document updates, default is true
                :track_destroy => true     # track document destruction, default is false


  extend Mongorder
  include HtmlScrubberUtil
#  validates_with Validations::DateRangeValidator

  GENDER_KINDS = %W(male female)

  IDENTIFYING_INFO_ATTRIBUTES = %w(first_name last_name ssn dob)
  ADDRESS_CHANGE_ATTRIBUTES = %w(addresses phones emails)
  RELATIONSHIP_CHANGE_ATTRIBUTES = %w(person_relationships)

  PERSON_CREATED_EVENT_NAME = "acapi.info.events.individual.created"
  PERSON_UPDATED_EVENT_NAME = "acapi.info.events.individual.updated"
  VERIFICATION_TYPES = ['Social Security Number', 'American Indian Status', 'Citizenship', 'Immigration status']

  NON_SHOP_ROLES = ['Individual','Coverall']

  field :hbx_id, type: String
  field :external_person_id, type: String
  field :name_pfx, type: String
  field :first_name, type: String
  field :middle_name, type: String
  field :last_name, type: String
  field :name_sfx, type: String
  field :full_name, type: String
  field :alternate_name, type: String

  field :encrypted_ssn, type: String
  field :gender, type: String
  field :dob, type: Date

  # Sub-model in-common attributes
  field :date_of_death, type: Date
  field :dob_check, type: Boolean

  field :is_incarcerated, type: Boolean

  field :is_disabled, type: Boolean
  field :ethnicity, type: Array
  field :race, type: String
  field :tribal_id, type: String
  field :tribal_state, type: String
  field :tribal_name, type: String
  field :tribe_codes, type: Array

  field :is_tobacco_user, type: String, default: "unknown"
  field :tobacco_use, type: Boolean # TODO: use above field
  field :language_code, type: String

  field :no_dc_address, type: Boolean, default: false
  field :no_dc_address_reason, type: String, default: ""

  field :is_active, type: Boolean, default: true
  field :age_off_excluded, type: Boolean, default: false
  field :updated_by, type: String
  field :no_ssn, type: String #ConsumerRole TODO TODOJF
  field :is_physically_disabled, type: Boolean
  field :is_applying_for_assistance, type: Boolean

  field :is_homeless, type: Boolean, default: false
  field :is_temporarily_out_of_state, type: Boolean, default: false
  field :is_moving_to_state, type: Boolean, default: false
  field :immigration_doc_statuses, type: Array

  # Mec check
  field :mec_check_response, type: String
  field :mec_check_date, type: DateTime
  # Used for recording payloads sent to CRM Gateway
  field :cv3_payload, type: Hash, default: {}
  field :crm_notifiction_needed, type: Boolean

  delegate :is_applying_coverage, to: :consumer_role, allow_nil: true

  # Login account
  belongs_to :user, inverse_of: :person, optional: true

  belongs_to :employer_contact,
                class_name: "EmployerProfile",
                inverse_of: :employer_contacts,
                index: true,
                optional: true

  belongs_to :broker_agency_contact,
                class_name: "BrokerAgencyProfile",
                inverse_of: :broker_agency_contacts,
                index: true,
                optional: true

  belongs_to :general_agency_contact,
                class_name: "GeneralAgencyProfile",
                inverse_of: :general_agency_contacts,
                index: true,
                optional: true

  embeds_one :consumer_role, cascade_callbacks: true, validate: true
  embeds_one :resident_role, cascade_callbacks: true, validate: true
  embeds_many :individual_market_transitions, cascade_callbacks: true, validate: true

  embeds_one :broker_role, cascade_callbacks: true, validate: true
  embeds_one :hbx_staff_role, cascade_callbacks: true, validate: true
  #embeds_one :responsible_party, cascade_callbacks: true, validate: true # This model does not exist.

  embeds_one :csr_role, cascade_callbacks: true, validate: true
  embeds_one :assister_role, cascade_callbacks: true, validate: true
  embeds_one :inbox, as: :recipient

  embeds_many :employer_staff_roles, cascade_callbacks: true, validate: true
  embeds_many :broker_agency_staff_roles, cascade_callbacks: true, validate: true
  embeds_many :employee_roles, cascade_callbacks: true, validate: true
  embeds_many :general_agency_staff_roles, cascade_callbacks: true, validate: true

  embeds_many :person_relationships, cascade_callbacks: true, validate: true
  embeds_many :addresses, cascade_callbacks: true, validate: true
  embeds_many :phones, cascade_callbacks: true, validate: true
  embeds_many :emails, cascade_callbacks: true, validate: true
  embeds_many :documents, as: :documentable
  embeds_many :verification_types, cascade_callbacks: true, validate: true

  # @!attribute [rw] demographics_group
  #   @return [DemographicsGroup] The demographics information for the person.
  #   This is a polymorphic association that can be associated with any model that can have demographics information.
  embeds_one :demographics_group, as: :demographicable, class_name: 'DemographicsGroup'

  attr_accessor :effective_date, :skip_person_updated_event_callback, :is_consumer_role, :is_resident_role

  accepts_nested_attributes_for :consumer_role, :resident_role, :broker_role, :hbx_staff_role,
    :person_relationships, :employee_roles, :phones, :employer_staff_roles

  accepts_nested_attributes_for :phones, :reject_if => Proc.new { |addy| addy[:full_phone_number].blank? }, allow_destroy: true
  accepts_nested_attributes_for :addresses, :reject_if => Proc.new { |addy| addy[:address_1].blank? && addy[:city].blank? && addy[:state].blank? && addy[:zip].blank? }, allow_destroy: true
  accepts_nested_attributes_for :emails, :reject_if => Proc.new { |addy| addy[:address].blank? }, allow_destroy: true

  validates_presence_of :first_name, :last_name
  validate :date_functional_validations
  validate :no_changing_my_user, :on => :update

  validates :encrypted_ssn, uniqueness: true, allow_blank: true

  validate :is_only_one_individual_role_active?

  validates :gender,
    allow_blank: true,
    inclusion: { in: Person::GENDER_KINDS, message: "%{value} is not a valid gender" }

  add_observer ::BenefitSponsors::Observers::EmployerStaffRoleObserver.new, :contact_changed?

  index({hbx_id: 1}, {sparse:true, unique: true})
  index({external_person_id: 1}, {sparse: true, unique: true})
  index({user_id: 1}, {sparse:true, unique: true})

  index({last_name:  1})
  index({first_name: 1})
  index({last_name: 1, first_name: 1})
  index({first_name: 1, last_name: 1})
  index({first_name: 1, last_name: 1, hbx_id: 1, encrypted_ssn: 1}, {name: "person_searching_index"})

  index({encrypted_ssn: 1}, {sparse: true, unique: true})
  index({dob: 1}, {sparse: true})
  index({dob: 1, encrypted_ssn: 1})

  index({hbx_id: 1, encrypted_ssn: 1}, {name: "person_search_hash_ssn_hbx_id"})
  index({last_name: 1, dob: 1}, {sparse: true})

  index({last_name: "text", first_name: "text", full_name: "text"}, {name: "person_search_text_index"})

  # Broker child model indexes
  index({"broker_role._id" => 1})
  index({"broker_role.provider_kind" => 1})
  index({"broker_role.broker_agency_id" => 1})
  index({"broker_role.benefit_sponsors_broker_agency_profile_id" => 1})
  index({"broker_role.npn" => 1}, {sparse: true, unique: true})

  index({"broker_agency_staff_roles.aasm_state" => 1})

  index({"general_agency_staff_roles.npn" => 1}, {sparse: true})
  index({"general_agency_staff_roles.is_primary" => 1})
  index({"general_agency_staff_roles.benefit_sponsors_general_agency_profile_id" => 1}, {sparse: true})
  index({"general_agency_staff_roles.aasm_state" => 1})

  index({"first_name" => 1, "last_name" => 1, "broker_role.npn" => 1}, {name: "first_name_last_name_broker_npn_search"})
  index({"first_name" => 1, "last_name" => 1, "general_agency_staff_roles.npn" => 1}, {name: "first_name_last_name_ga_npn_search"})

  index({
          "general_agency_staff_roles.benefit_sponsors_general_agency_profile_id" => 1,
          "general_agency_staff_roles.is_primary" => 1
        }, {name: "agency_search_by_id_and_is_primary"})

  # Employer role index
  index({"employer_staff_roles._id" => 1})
  index({"employer_staff_roles.employer_profile_id" => 1})
  index({"employer_staff_roles.benefit_sponsor_employer_profile_id" => 1})

  # Consumer child model indexes
  index({"consumer_role._id" => 1})
  index({"consumer_role.aasm_state" => 1})
  index({"consumer_role.is_active" => 1})

  # Employee child model indexes
  index({"employee_roles._id" => 1})
  index({"employee_roles.employer_profile_id" => 1})
  index({"employee_roles.census_employee_id" => 1})
  index({"employee_roles.benefit_group_id" => 1})
  index({"employee_roles.is_active" => 1})

  # HbxStaff child model indexes
  index({"hbx_staff_role._id" => 1})
  index({"hbx_staff_role.is_active" => 1})

  # PersonRelationship child model indexes
  index({"person_relationship.relative_id" =>  1})

  index({"hbx_employer_staff_role._id" => 1})

  #index({"hbx_responsible_party_role._id" => 1})

  index({"hbx_csr_role._id" => 1})
  index({"hbx_assister._id" => 1})

  index(
    {"broker_agency_staff_roles._id" => 1},
    {name: "person_broker_agency_staff_role_id_search"}
  )

  index({ "verification_types.validation_status" => 1 })

  index({ "consumer_role.eligibilities.key" => 1 })
  index({ "resident_role.eligibilities.key" => 1 })

  scope :all_consumer_roles,          -> { exists(consumer_role: true) }
  scope :all_resident_roles,          -> { exists(resident_role: true) }
  scope :all_employee_roles,          -> { exists(employee_roles: true) }
  scope :all_employer_staff_roles,    -> { exists(employer_staff_roles: true) }
  scope :all_individual_market_transitions,  -> { exists(individual_market_transitions: true) }

  #scope :all_responsible_party_roles, -> { exists(responsible_party_role: true) }
  scope :all_broker_roles,            -> { exists(broker_role: true) }
  scope :all_hbx_staff_roles,         -> { exists(hbx_staff_role: true) }
  scope :all_csr_roles,               -> { exists(csr_role: true) }
  scope :all_assister_roles,          -> { exists(assister_role: true) }
  scope :all_broker_staff_roles,      -> { exists(broker_agency_staff_roles: true) }
  scope :all_agency_staff_roles,      -> do
    where(
      {
      "$or" => [
          { "broker_agency_staff_roles" => { "$exists" => true } },
          { "general_agency_staff_roles" => { "$exists" => true }, "general_agency_staff_roles.is_primary" => {"$ne" => false} }
        ]
      }
    )
  end

  scope :by_hbx_id, ->(person_hbx_id) { where(hbx_id: person_hbx_id) }
  scope :by_broker_role_npn, ->(br_npn) { where("broker_role.npn" => br_npn) }
  scope :active,   ->{ where(is_active: true) }
  scope :inactive, ->{ where(is_active: false) }

  #scope :broker_role_having_agency, -> { where("broker_role.broker_agency_profile_id" => { "$ne" => nil }) }
  scope :broker_role_having_agency, -> { where("broker_role.benefit_sponsors_broker_agency_profile_id" => { "$ne" => nil }) }
  scope :broker_role_applicant,     -> { where("broker_role.aasm_state" => { "$eq" => :applicant })}
  scope :broker_role_pending,       -> { where("broker_role.aasm_state" => { "$eq" => :broker_agency_pending })}
  scope :broker_role_certified,     -> { where("broker_role.aasm_state" => { "$in" => [:active]})}
  scope :broker_role_decertified,   -> { where("broker_role.aasm_state" => { "$eq" => :decertified })}
  scope :broker_role_extended,      -> { where("broker_role.aasm_state" => { "$eq" => :application_extended })}
  scope :broker_role_imported,      -> { where("broker_role.aasm_state" => { "$eq" => :imported })}
  scope :broker_role_denied,        -> { where("broker_role.aasm_state" => { "$eq" => :denied })}
  scope :by_ssn,                    ->(ssn) { where(encrypted_ssn: Person.encrypt_ssn(ssn)) }
  scope :unverified_persons,        -> { where(:'consumer_role.aasm_state' => { "$ne" => "fully_verified" })}
  scope :matchable,                 ->(ssn, dob, last_name) { where(encrypted_ssn: Person.encrypt_ssn(ssn), dob: dob, last_name: last_name) }
  scope :broker_staff_active_or_pending, -> { where("broker_agency_staff_roles.aasm_state" => { "$in" => [:broker_agency_pending, :active] }) }
  scope :staff_for_broker_including_pending, ->(broker_profile) { where("broker_agency_staff_roles.benefit_sponsors_broker_agency_profile_id" => broker_profile.id).broker_staff_active_or_pending }
  scope :staff_for_ga_including_pending, lambda { |general_agency_profile|
    where("general_agency_staff_roles.benefit_sponsors_general_agency_profile_id" => general_agency_profile.id)
      .where("general_agency_staff_roles.aasm_state" => { "$in" => [:general_agency_pending, :active] })
  }

  scope :general_agency_staff_applicant,     -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :applicant })}
  scope :general_agency_staff_certified,     -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :active })}
  scope :general_agency_staff_decertified,   -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :decertified })}
  scope :general_agency_staff_denied,        -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :denied })}
  # scope :general_agency_primary_staff,     -> { where("general_agency_staff_roles.is_primary" => { "$eq" => true })}

  scope :outstanding_identity_validation, -> { where(:'consumer_role.identity_validation' => { "$in" => [:pending, :rejected] })}
  scope :identity_validation_documents, -> { where(:'consumer_role.ridp_documents.ridp_verification_type' => "Identity") }
  scope :outstanding_application_validation, -> { where(:'consumer_role.application_validation' => { "$in" => [:pending, :rejected] })}
  scope :application_validation_documents, -> { where(:'consumer_role.ridp_documents.ridp_verification_type' => "Application") }
  scope :for_admin_approval, -> { any_of([outstanding_identity_validation.selector, outstanding_application_validation.selector]) }
  scope :for_admin_approval_with_documents, -> {any_of([outstanding_identity_validation.identity_validation_documents.selector, outstanding_application_validation.application_validation_documents.selector])}

  scope :only_text_notifications, -> { where(:'consumer_role.contact_method' => ConsumerRole::CONTACT_METHOD_MAPPING[["Text"]]) }

  # People with at least one verification_type in rejected status
  scope :rejected_verification_type, -> { where(:'verification_types.validation_status' => 'rejected') }

#  ViewFunctions::Person.install_queries

  validate :consumer_fields_validations

  before_save :generate_hbx_id
  before_save :update_full_name
  before_save :strip_empty_fields
  before_save :check_indian if EnrollRegistry[:indian_alaskan_tribe_details].enabled?
  before_save :check_crm_updates
  after_create :create_inbox
  after_create :notify_created
  after_update :notify_updated
  after_update :person_create_or_update_handler
  after_save :generate_person_saved_event
  after_update :publish_updated_event
  after_initialize :set_default_tobacco_use

  def self.api_staff_roles
    Person.where(
      {
      "is_active" => true,
      "$or" => [
          { "broker_agency_staff_roles" => { "$exists" => true, "$not" => {"$size" => 0} } },
          { "general_agency_staff_roles.is_primary" =>  false }
        ]
      }
    )
  end

  def self.api_primary_staff_roles
    Person.where(
      {
      "is_active" => true,
      "$or" => [
          { "broker_role._id" => {"$exists" => true} },
          { "general_agency_staff_roles.is_primary" =>  true }
        ]
      }
    )
  end

  def agency_roles
    role_data(broker_agency_staff_roles, :benefit_sponsors_broker_agency_profile_id) + role_data(general_agency_staff_roles, :benefit_sponsors_general_agency_profile_id)
  end

  def role_data(data, agency)
    data.collect do |role|
      {
        aasm_state: role.aasm_state,
        agency_profile_id: role.try(agency).to_s,
        type: role.class.name,
        role_id: role._id.to_s,
        history: role.workflow_state_transitions
      }
    end
  end

  def agent_emails
    self.emails.collect do |email|
      {
        id: email.id.to_s,
        kind: email.kind,
        address: email.address
      }
    end
  end

  def has_active_enrollment
    if self.families.present?
      self.families.each do |family|
        household = family.active_household
        if household && household.hbx_enrollments.where(:'aasm_state'.in => HbxEnrollment::ENROLLED_AND_RENEWAL_STATUSES).present?
          return true
        end
      end
    end
    false
  end

  def ethnicity
    # Retrieve the raw 'ethnicity' value from the database
    # Return an empty array if 'ethnicity' is nil, ensuring consistent array behavior
    read_attribute(:ethnicity) || []
  end

  def tribe_codes
    # Retrieve the raw 'tribe_codes' value from the database
    # Return an empty array if 'tribe_codes' is nil, ensuring consistent array behavior
    read_attribute(:tribe_codes) || []
  end

  def accept(visitor)
    verification_types.active.each do |verification_type|
      verification_type.accept(visitor)
    end
  end

  def agent_npn
    self.general_agency_staff_roles.select{|role| role.is_primary }.try(:first).try(:npn) || self.broker_role.try(:npn)
  end

  def agent_role_id
    self.general_agency_staff_roles.select{|role| role.is_primary }.try(:first).try(:id) || self.broker_role.try(:id)
  end

  def connected_profile_id
    self.general_agency_staff_roles.select{|role| role.is_primary }.try(:first).try(:benefit_sponsors_general_agency_profile_id) || self.broker_role.try(:benefit_sponsors_broker_agency_profile_id)
  end

  def active_general_agency_staff_roles
    general_agency_staff_roles.where(:aasm_state => :active)
  end

  def has_active_general_agency_staff_role?
    !active_general_agency_staff_roles.empty?
  end

  def contact_addresses
    existing_addresses = addresses.to_a
    home_address = existing_addresses.detect { |addy| addy.kind == "home" }
    return existing_addresses if home_address
    add_employee_home_address(existing_addresses)
  end

  def add_employee_home_address(existing_addresses)
    return existing_addresses unless employee_roles.any?
    employee_contact_address = employee_roles.sort_by(&:hired_on).map(&:census_employee).compact.map(&:address).compact.first
    return existing_addresses unless employee_contact_address
    existing_addresses + [employee_contact_address]
  end

  def contact_phones
    phones.reject { |ph| ph.full_phone_number.blank? }
  end

  delegate :citizen_status, :citizen_status=, :to => :consumer_role, :allow_nil => true
  delegate :ivl_coverage_selected, :to => :consumer_role, :allow_nil => true
  delegate :all_types_verified?, :to => :consumer_role

  def notify_created
    notify(PERSON_CREATED_EVENT_NAME, {:individual_id => self.hbx_id } )
  end

  def notify_updated
    notify(PERSON_UPDATED_EVENT_NAME, {:individual_id => self.hbx_id } )
  end

  def generate_person_saved_event
    if EnrollRegistry.feature_enabled?(:async_publish_updated_families)

      # TODO: Refactor to capture embedded changed attributes in Person object changed_attributes
      embedded_changed_attributes = {
        changed_person_attributes: changed_attributes,
        changed_address_attributes: changed_address_attributes,
        changed_phone_attributes: changed_phone_attributes,
        changed_email_attributes: changed_email_attributes,
        changed_relationship_attributes: changed_relationship_attributes
      }

      event(
        'events.private.person_saved',
        headers: {
          after_updated_at: convert_time_to_string(updated_at),
          before_updated_at: convert_time_to_string(changed_attributes.deep_symbolize_keys[:updated_at])
        },
        attributes: {
          after_save_version: to_hash,
          changed_attributes: embedded_changed_attributes
        }
      ).success&.publish
    else
      cv_person = Operations::Transformers::PersonTo::Cv3Person.new.call(self)
      event = event('events.person_saved', attributes: {gid: self.to_global_id.uri, payload: cv_person})
      event.success.publish if event.success?
    end
  rescue StandardError => e
    Rails.logger.error { "Couldn't generate person save event due to #{e.backtrace}" }
  end

  def publish_updated_event
    return if skip_person_updated_event_callback

    event = event('events.person_updated', attributes: { gid: self.to_global_id.uri, payload: self.changed_attributes })
    event.success.publish if event.success?
  rescue StandardError => e
    Rails.logger.error { "Couldn't generate person update event due to #{e.backtrace}" }
  end

  def person_create_or_update_handler
    ::Operations::FinancialAssistance::PersonCreateOrUpdateHandler.new.call({person: self, event: :person_updated}) if ::EnrollRegistry.feature_enabled?(:financial_assistance)
  rescue StandardError => e
    Rails.logger.error {"FAA Engine: Unable to do action Operations::FinancialAssistance::PersonCreateOrUpdateHandler for person with object_id: #{self.id} due to #{e.message}"}
  end

  def completed_identity_verification?
    return false unless user
    user.identity_verified?
  end

  def generate_hbx_id
    write_attribute(:hbx_id, HbxIdGenerator.generate_member_id) if hbx_id.blank?
  end

  def set_default_tobacco_use
    self.is_tobacco_user = "unknown" if EnrollRegistry.feature_enabled?(:sensor_tobacco_carrier_usage)
  end

  def strip_empty_fields
    if encrypted_ssn.blank?
      unset_sparse("encrypted_ssn")
    end

    if user_id.blank?
      unset_sparse("user_id")
    end
  end

  def date_of_birth=(val)
    self.dob = Date.strptime(val, "%m/%d/%Y").to_date rescue nil
  end

  def gender=(new_gender)
    write_attribute(:gender, new_gender.to_s.downcase)
  end

  def financial_assistance_identifier
    primary_family&.id
  end

  # Get the {Family} where this {Person} is the primary family member
  #
  # family itegrity ensures only one active family can be the primary for a person
  #
  # @return [ Family ] the family member who matches this person
  def primary_family
    @primary_family ||= Family.find_primary_applicant_by_person(self).first
  end

  def families
    Family.find_all_by_person(self)
  end

  def full_name
    @full_name = [name_pfx, first_name, middle_name, last_name, name_sfx].compact.join(" ")
  end

  def first_name_last_name_and_suffix(seperator=nil)
    seperator = seperator.present? ? seperator : " "
    [first_name, last_name, name_sfx].compact.join(seperator)
    case name_sfx
      when "ii" ||"iii" || "iv" || "v"
        [first_name.capitalize, last_name.capitalize, name_sfx.upcase].compact.join(seperator)
      else
        [first_name.capitalize, last_name.capitalize, name_sfx].compact.join(seperator)
      end
  end

  def is_active?
    is_active
  end

  def deactivate_types(types)
    types.each do |type|
      verification_type_by_name(type).update_attributes(:inactive => true) unless verification_type_by_name(type).inactive
    end
  end

  # Adds a new verification type to the person.
  #
  # If the verification type already exists, it reactivates it by setting `inactive` to false.
  # If the verification type does not exist, it creates a new verification type with the default status.
  #
  # @param new_type [String] the name of the new verification type to add.
  # @return [void]
  def add_new_verification_type(new_type)
    default_status = default_verification_type_status(new_type)
    if verification_types.map(&:type_name).include? new_type
      verification_type_by_name(new_type).update_attributes(:inactive => false)
    else
      verification_types << VerificationType.new(:type_name => new_type, :validation_status => default_status ) if !(us_citizen.nil?)
    end
  end

  # Finds a verification type by its name.
  #
  # @param type [String] the name of the verification type to find.
  # @return [VerificationType, nil] the verification type with the given name, or nil if not found.
  def verification_type_by_name(type)
    verification_types.find_by(:type_name => type)
  end

  # Determines the default verification status for a given verification type.
  #
  # @param type [String] the name of the verification type.
  # @return [String] the default verification status for the given type.
  #   - "attested" if the type is `VerificationType::AMERICAN_INDIAN_STATUS`.
  #   - "attested" if the type is `VerificationType::LOCATION_RESIDENCY` and the person is consumer/resident under 18 years old.
  #   - "unverified" otherwise.
  def default_verification_type_status(type)
    case type
    when VerificationType::LOCATION_RESIDENCY
      (consumer_role || resident_role) && age_on(TimeKeeper.date_of_record) < 18 ? "attested" : "unverified"
    when VerificationType::AMERICAN_INDIAN_STATUS
      "attested"
    else
      "unverified"
    end
  end

# collect all ridp_verification_types user in case of unsuccessful ridp
  def ridp_verification_types
    ridp_verification_types = []
    if consumer_role && !consumer_role.person.completed_identity_verification?
      ridp_verification_types << 'Identity'
      ridp_verification_types << 'Application' if EnrollRegistry.feature_enabled?(:paper_application_verification)
    end
    ridp_verification_types
  end

  def relatives
    person_relationships.reject do |p_rel|
      p_rel.relative_id.to_s == self.id.to_s
    end.map(&:relative)
  end

  def find_relationship_with(other_person)
    if self.id == other_person.id
      "self"
    else
      person_relationship_for(other_person).try(:kind)
    end
  end

  def person_relationship_for(other_person)
    person_relationships.detect do |person_relationship|
      person_relationship.relative_id == other_person.id
    end
  end

  def ensure_relationship_with(person, relationship)
    return if person.blank?
    existing_relationship = self.person_relationships.detect do |rel|
      rel.relative_id.to_s == person.id.to_s
    end
    if existing_relationship
      existing_relationship.kind = relationship
      save
    elsif id != person.id
      self.person_relationships << PersonRelationship.new({
                                                            :kind => relationship,
                                                            :relative_id => person.id
                                                          })
    end
  end

  def add_work_email(email)
    existing_email = self.emails.detect do |e|
      (e.kind == 'work') &&
        (e.address.downcase == email.downcase)
    end
    return nil if existing_email.present?
    self.emails << ::Email.new(:kind => 'work', :address => email)
  end

  def home_address
    addresses.detect { |adr| adr.kind == "home" }
  end

  def zip
    home_address.zip
  end

  def mailing_address
    addresses.detect { |adr| adr.kind == "mailing" } || home_address
  end

  def has_mailing_address?
    addresses.any? { |adr| adr.kind == "mailing" }
  end

  def rating_address
    home_address || mailing_address
  end

  def home_email
    emails.detect { |adr| adr.kind == "home" }
  end

  def work_email
    emails.detect { |adr| adr.kind == "work" }
  end

  def work_email_or_best
    email = emails.detect { |adr| adr.kind == "work" } || emails.first
    (email && email.address) || (user && user.email)
  end

  def work_phone
    phones.detect { |phone| phone.kind == "work" } || main_phone
  end

  def main_phone
    phones.detect { |phone| phone.kind == "main" }
  end

  def home_phone
    phones.detect { |phone| phone.kind == "home" }
  end

  def mobile_phone
    phones.detect { |phone| phone.kind == "mobile" }
  end

  def work_phone_or_best
    best_phone  = work_phone || mobile_phone || home_phone
    best_phone ? best_phone.full_phone_number : nil
  end

  def has_active_consumer_role?
     consumer_role.present? && consumer_role.is_active?
  end

  def has_active_resident_role?
    resident_role.present? && resident_role.is_active?
  end

  def has_active_resident_member?
    if self.primary_family.present?
      active_resident_member = self.primary_family.active_family_members.detect { |member| member.person.is_resident_role_active? }
      return true if active_resident_member.present?
    end
    return false
  end

  def has_active_consumer_member?
    if self.primary_family.present?
      active_consumer_member = self.primary_family.active_family_members.detect { |member| member.person.is_consumer_role_active? }
      return true if active_consumer_member.present?
    end
    return false
  end

  def can_report_shop_qle?
    employee_roles.first.census_employee.qle_30_day_eligible?
  end

  def has_active_employee_role?
    return false unless is_shop_or_fehb_market_enabled?
    active_employee_roles.any?
  end

  def has_employer_benefits?
    active_employee_roles.present? #&& active_employee_roles.any?{|r| r.benefit_group.present?}
  end

  def active_employee_roles
    return [] unless is_shop_or_fehb_market_enabled?
    employee_roles.select{|employee_role| employee_role.census_employee && employee_role.census_employee.is_active? }
  end

  def has_multiple_active_employers?
    active_employee_roles.count > 1
  end

  def has_active_employer_staff_role?
    employer_staff_roles.present? and employer_staff_roles.active.present?
  end

  def active_employer_staff_roles
    employer_staff_roles.present? ? employer_staff_roles.active : []
  end

  def has_multiple_roles?
    consumer_role.present? && active_employee_roles.present?
  end

  def has_active_employee_role_for_census_employee?(census_employee)
    if census_employee
      (active_employee_roles.detect { |employee_role| employee_role.census_employee == census_employee }).present?
    end
  end

  def residency_eligible?
    is_homeless? || is_temporarily_out_of_state?
  end

  def age_on(date)
    age = date.year - dob.year
    if date.month < dob.month || (date.month == dob.month && date.day < dob.day)
      age - 1
    else
      age
    end
  rescue StandardError
    self.errors.add(:base, l10n("exceptions.valid_birthdate"))
  end

  def is_homeless?
    is_homeless
  end

  def is_temporarily_out_of_state?
    is_temporarily_out_of_state
  end

  def is_dc_resident?
    return true if is_homeless? || is_temporarily_out_of_state?

    address_to_use = addresses.collect(&:kind).include?('home') ? 'home' : 'mailing'
    addresses.each{|address| return true if address.kind == address_to_use && address.state == aca_state_abbreviation}
    false
  end

  def current_individual_market_transition
    if self.individual_market_transitions.present?
      self.individual_market_transitions.last
    else
      nil
    end
  end

  def active_individual_market_role
    if current_individual_market_transition.present? && current_individual_market_transition.role_type
      current_individual_market_transition.role_type
    else
      nil
    end
  end

  def has_consumer_or_resident_role?
    is_consumer_role_active? || is_resident_role_active?
  end

  def is_consumer_role_active?
    self.active_individual_market_role == "consumer" ? true : false
  end

  def is_resident_role_active?
     self.active_individual_market_role == "resident" ? true : false
  end

  def has_pending_broker_staff_role?(broker_agency_profile_id)
    broker_agency_staff_roles.where({
                                      aasm_state: :broker_agency_pending,
                                      '$or' => [
                                        {benefit_sponsors_broker_agency_profile_id: broker_agency_profile_id},
                                        {broker_agency_profile_id: broker_agency_profile_id}
                                      ]
                                    }).size > 0
  end

  def has_pending_ga_staff_role?(general_agency_profile_id)
    general_agency_staff_roles.where({
                                      aasm_state: :general_agency_pending,
                                      '$or' => [
                                        {benefit_sponsors_general_agency_profile_id: general_agency_profile_id},
                                        {general_agency_profile_id: general_agency_profile_id}
                                      ]
                                    }).size > 0
  end

  def active_broker_staff_roles
    broker_agency_staff_roles.where(:aasm_state => :active)
  end

  def has_active_broker_staff_role?
    !active_broker_staff_roles.empty?
  end

  def general_agency_primary_staff
    general_agency_staff_roles.present? ? general_agency_staff_roles.where(is_primary: true).first : nil
  end

  class << self

    def full_name_field_pipeline
      {:$trim =>
        {:input =>
          {:$concat =>
            ["$first_name", " ", "$last_name"]}}}
    end

    def sort_by_full_name_pipeline(sort_direction)
      [
        {:$addFields => { :full_name => full_name_field_pipeline }},
        {:$sort => { :full_name => sort_direction }}
      ]
    end

    def default_search_order
      [[:last_name, 1],[:first_name, 1]]
    end

    def search_hash(s_str)
      clean_str = s_str.strip
      s_rex = Regexp.new("^" + Regexp.escape(clean_str), true)
      if clean_str =~ /[a-z]/i
          {
            "$or" => ([
              {"first_name" => s_rex},
              {"last_name" => s_rex}
            ] + additional_exprs(clean_str))
          }
      else
        {
          "$or" => [
            {"hbx_id" => s_rex},
            {"encrypted_ssn" => encrypt_ssn(clean_str)}
          ]
        }
      end
    end

    def broker_ga_search_hash(s_str)
      clean_str = s_str.strip
      s_rex = Regexp.new("^" + Regexp.escape(clean_str), true)
      if clean_str =~ /[a-z]/i
        {
          "$or" => ([
            {"first_name" => s_rex},
            {"last_name" => s_rex},
          ] + additional_exprs(clean_str))
        }
      else
        {
          "$or" => [
            {"broker_role.npn" => s_rex},
            {"general_agency_staff_roles.npn" => s_rex}
          ]
        }
      end
    end

    def additional_exprs(clean_str)
      additional_exprs = []
      if clean_str.include?(" ")
        parts = clean_str.split(" ").compact
        first_re = ::Regexp.new(::Regexp.escape(parts.first), true)
        last_re = ::Regexp.new(::Regexp.escape(parts.last), true)
        additional_exprs << {:first_name => first_re, :last_name => last_re}
      end
      additional_exprs
    end

    def search_first_name_last_name_npn(s_str, query = self)
      clean_str = s_str.strip
      if clean_str =~ /[a-z]/i
        people_user_ids = query.collection.aggregate([
                            {"$match" => {
                              "$text" => {"$search" => clean_str}
                            }.merge(Person.broker_ga_search_hash(clean_str))},
                            {"$project" => {"first_name" => 1, "last_name" => 1, "full_name" => 1}},
                            {"$sort" => {"last_name" => 1, "first_name" => 1}},
                            {"$project" => {"_id" => 1}}
                          ], {allowDiskUse: true}).map do |rec|
                            rec["_id"]
                          end
        query.where(:id => {"$in" => people_user_ids})
      else
        query.where(broker_ga_search_hash(s_str))
      end
    end

    def brokers_matching_search_criteria(search_str)
      broker_role_certified.search_first_name_last_name_npn(search_str)
    end

    def agencies_with_matching_broker(search_str)
      if brokers_matching_search_criteria(search_str).exists(:"broker_role.benefit_sponsors_broker_agency_profile_id" => true)
        brokers_matching_search_criteria(search_str).map(&:broker_role).map(&:benefit_sponsors_broker_agency_profile_id)
      else
        brokers_matching_search_criteria(search_str).map(&:broker_role).map(&:broker_agency_profile_id)
      end
    end

    def general_agencies_matching_search_criteria(search_str)
      general_agency_staff_certified.search_first_name_last_name_npn(search_str)
    end

    # Find all employee_roles.  Since person has_many employee_roles, person may show up
    # employee_role.person may not be unique in returned set
    def employee_roles
      people = exists(:'employee_roles.0' => true).entries
      people.flat_map(&:employee_roles)
    end

    def find_all_brokers_or_staff_members_by_agency(broker_agency)
      Person.or({:"broker_role.broker_agency_profile_id" => broker_agency.id},
                {:"broker_agency_staff_roles.broker_agency_profile_id" => broker_agency.id})
    end

    def sans_primary_broker(broker_agency)
      where(:"broker_role._id".nin => [broker_agency.primary_broker_role_id])
    end

    def find_all_staff_roles_by_employer_profile(employer_profile)
      #where({"$and"=>[{"employer_staff_roles.employer_profile_id"=> employer_profile.id}, {"employer_staff_roles.is_owner"=>true}]})
      staff_for_employer(employer_profile)
    end

    def match_existing_person(personish)
      return nil if personish.ssn.blank?
      Person.where(:encrypted_ssn => encrypt_ssn(personish.ssn), :dob => personish.dob).first
    end

    def person_has_an_active_enrollment?(person)
      if !person.primary_family.blank? && !person.primary_family.enrollments.blank?
        person.primary_family.enrollments.each do |enrollment|
          return true if enrollment.is_active
        end
      end
      return false
    end

    def dob_change_implication_on_active_enrollments(person, new_dob)
      # This method checks if there is a premium implication in all active enrollments when a persons DOB is changed.
      # Returns a hash with Key => HbxEnrollment ID and, Value => true if  enrollment has Premium Implication.
      premium_impication_for_enrollment = Hash.new
      active_enrolled_hbxs = person.primary_family.active_household.hbx_enrollments.active.enrolled_and_renewal

      # Iterate over each enrollment and check if there is a Premium Implication based on the following rule:
      # Rule: There are Implications when DOB changes makes anyone in the household a different age on the day coverage started UNLESS the
      #       change is all within the 0-20 age range or all within the 61+ age range (20 >= age <= 61)
      active_enrolled_hbxs.each do |hbx|
        new_temp_person = person.dup
        new_temp_person.dob = Date.strptime(new_dob.to_s, '%m/%d/%Y')
        new_age     = new_temp_person.age_on(hbx.effective_on)  # age with the new DOB on the day coverage started
        current_age = person.age_on(hbx.effective_on)           # age with the current DOB on the day coverage started

        next if new_age == current_age # No Change in age -> No Premium Implication

        # No Implication when the change is all within the 0-20 age range or all within the 61+ age range
        if ( current_age.between?(0,20) && new_age.between?(0,20) ) || ( current_age >= 61 && new_age >= 61 )
          #premium_impication_for_enrollment[hbx.id] = false
        else
          premium_impication_for_enrollment[hbx.id] = true
        end
      end
      premium_impication_for_enrollment
    end

    # Return an instance list of active People who match identifying information criteria
    def match_by_id_info(options)
      ssn_query = options[:ssn]
      dob_query = options[:dob]
      last_name = options[:last_name]
      first_name = options[:first_name]

      raise ArgumentError, "must provide an ssn or first_name/last_name/dob or both" if (ssn_query.blank? && (dob_query.blank? || last_name.blank? || first_name.blank?))

      matches = Array.new
      matches.concat Person.active.where(encrypted_ssn: encrypt_ssn(ssn_query), dob: dob_query).to_a unless ssn_query.blank?
      #matches.concat Person.where(last_name: last_name, dob: dob_query).active.to_a unless (dob_query.blank? || last_name.blank?)
      if first_name.present? && last_name.present? && dob_query.present?
        first_exp = /^#{first_name}$/i
        last_exp = /^#{last_name}$/i
        matches.concat Person.active.where(dob: dob_query, last_name: last_exp, first_name: first_exp).to_a.select{|person| person.ssn.blank? || ssn_query.blank?}
      end
      matches.uniq
    end

    def brokers_or_agency_staff_with_status(query, status)
      query.and(
                Person.or(
                          { :"broker_agency_staff_roles.aasm_state" => status },
                          { :"broker_role.aasm_state" => status }
                         ).selector
               )
    end

    def staff_for_employer(employer_profile)
      if employer_profile.is_a? (EmployerProfile)
        self.where(:employer_staff_roles => {
            '$elemMatch' => {
                employer_profile_id: employer_profile.id,
                aasm_state: :is_active}
        }).to_a
      else
        self.where(:employer_staff_roles => {
            '$elemMatch' => {
                benefit_sponsor_employer_profile_id: employer_profile.id,
                aasm_state: :is_active}
        }).to_a
      end
    end

    def staff_for_broker(broker_profile)
      Person.where(:broker_agency_staff_roles =>
                     {
                       '$elemMatch' =>
                         {
                           aasm_state: :active,
                           '$or' => [
                             {benefit_sponsors_broker_agency_profile_id: broker_profile.id},
                             {broker_agency_profile_id: broker_profile.id}
                           ]
                         }
                     })
    end

    def staff_for_ga(general_agency_profile)
      Person.where(:general_agency_staff_roles =>
                     {
                       '$elemMatch' =>
                         {
                           aasm_state: :active,
                           '$or' => [
                             {benefit_sponsors_general_agency_profile_id: general_agency_profile.id},
                             {general_agency_profile_id: general_agency_profile.id}
                           ]
                         }
                     })
    end

    def staff_for_employer_including_pending(employer_profile)
      if employer_profile.is_a? (EmployerProfile)
        self.where(:employer_staff_roles => {
            '$elemMatch' => {
                employer_profile_id: employer_profile.id,
                :aasm_state.ne => :is_closed
            }
        })
      else
        self.where(:employer_staff_roles => {
            '$elemMatch' => {
                benefit_sponsor_employer_profile_id: employer_profile.id,
                :aasm_state.ne => :is_closed
            }
        })
      end
    end

    # Adds employer staff role to person
    # Returns status and message if failed
    # Returns status and person if successful
    def add_employer_staff_role(first_name, last_name, dob, email, employer_profile)
      person = Person.where(first_name: /^#{first_name}$/i, last_name: /^#{last_name}$/i, dob: dob)

      return false, 'Person count too high, please contact HBX Admin' if person.count > 1
      return false, 'Person does not exist on the HBX Exchange' if person.count == 0

      if employer_profile.is_a? (EmployerProfile)
        employer_staff_role = EmployerStaffRole.create(person: person.first, employer_profile_id: employer_profile._id)
      else
        employer_staff_role = EmployerStaffRole.create(person: person.first, benefit_sponsor_employer_profile_id: employer_profile._id)
      end

      employer_staff_role.save

      return true, person.first
    end

    # Sets employer staff role to inactive
    # Returns false if person not found
    # Returns false if employer staff role not matches
    # Returns true is role was marked inactive
    def deactivate_employer_staff_role(person_id, employer_profile_id)

      begin
        person = Person.find(person_id)
      rescue
        return false, 'Person not found'
      end
      if role = person.employer_staff_roles.detect{|role| (role.benefit_sponsor_employer_profile_id.to_s == employer_profile_id.to_s || role.employer_profile_id.to_s == employer_profile_id.to_s) && !role.is_closed?}
        role.update_attributes!(:aasm_state => :is_closed)
        return true, 'Employee Staff Role is inactive'
      else
        return false, 'No matching employer staff role'
      end
    end
  end

  # HACK
  # FIXME
  # TODO: Move this out of here
  attr_writer :us_citizen, :naturalized_citizen, :indian_tribe_member, :eligible_immigration_status

  before_save :assign_citizen_status_from_consumer_role

  def assign_citizen_status_from_consumer_role
    if is_consumer_role.to_s=="true"
      assign_citizen_status
    end
  end

  def us_citizen=(val)
    @us_citizen = (val.to_s == "true")
    @naturalized_citizen = false if val.to_s == "false"
  end

  def skip_lawful_presence_determination_callbacks=(val)
    @skip_lawful_presence_determination_callbacks = true if val.to_s == "true"
  end

  def naturalized_citizen=(val)
    @naturalized_citizen = (val.to_s == "true")
  end

  def indian_tribe_member=(val)
    if EnrollRegistry[:indian_alaskan_tribe_details].enabled?
      if val.to_s == 'false'
        self.tribal_state = nil
        self.tribal_name = nil
        self.tribal_id = nil
      end
    elsif val.to_s == false
      self.tribal_id = nil
    end
    @indian_tribe_member = (val.to_s == "true")
  end

  def check_indian
    return unless @indian_tribe_member.to_s == 'false'
    self.tribal_id = nil
    self.tribal_state = nil
    self.tribal_name = nil
  end

  def check_crm_updates
    return unless EnrollRegistry.feature_enabled?(:check_for_crm_updates)
    write_attribute(:crm_notifiction_needed, true) if crm_attributes_changed?
  end

  def crm_attributes_changed?
    encrypted_ssn_change || first_name_change || last_name_change || dob_change
  end

  def eligible_immigration_status=(val)
    @eligible_immigration_status = (val.to_s == "true")
  end

  def us_citizen
    return @us_citizen if !@us_citizen.nil?
    return nil if citizen_status.blank?
    @us_citizen ||= ::ConsumerRole::US_CITIZEN_STATUS_KINDS.include?(citizen_status)
  end

  def naturalized_citizen
    return @naturalized_citizen if !@naturalized_citizen.nil?
    return nil if citizen_status.blank?
    @naturalized_citizen ||= (::ConsumerRole::NATURALIZED_CITIZEN_STATUS == citizen_status)
  end

  def indian_tribe_member
    return @indian_tribe_member if !@indian_tribe_member.nil?
    return nil if citizen_status.blank?

    result = @indian_tribe_member ||= !(tribal_id.nil? || tribal_id.empty?)
    result = @indian_tribe_member ||= !(tribal_state.nil? || tribal_state.empty?) if EnrollRegistry[:indian_alaskan_tribe_details].enabled?
    result
  end

  def eligible_immigration_status
    return @eligible_immigration_status if !@eligible_immigration_status.nil?
    return nil if us_citizen.nil?
    return nil if @us_citizen
    return nil if citizen_status.blank?
    @eligible_immigration_status ||= (::ConsumerRole::ALIEN_LAWFULLY_PRESENT_STATUS == citizen_status)
  end

  def assign_citizen_status
    new_status = nil
    if naturalized_citizen
      new_status = ::ConsumerRole::NATURALIZED_CITIZEN_STATUS
    elsif us_citizen
      new_status = ::ConsumerRole::US_CITIZEN_STATUS
    elsif eligible_immigration_status
      new_status = ::ConsumerRole::ALIEN_LAWFULLY_PRESENT_STATUS
    elsif (!eligible_immigration_status.nil?)
      new_status = ::ConsumerRole::NOT_LAWFULLY_PRESENT_STATUS
    elsif
      self.errors.add(:base, "Citizenship status can't be nil.")
    end
    lawful_presence_determination = self.consumer_role.lawful_presence_determination
    lawful_presence_determination.skip_lawful_presence_determination_callbacks = @skip_lawful_presence_determination_callbacks if @skip_lawful_presence_determination_callbacks == true
    lawful_presence_determination.assign_citizen_status(new_status) if new_status
  end

  def agent?
    agent = csr_role || assister_role || broker_role || hbx_staff_role || general_agency_staff_roles.present? || broker_agency_staff_roles.present?
    !!agent
  end

  def contact_info(email_address, area_code, number, extension)
    if email_address.present?
      email = emails.detect{|mail|mail.kind == 'work'}
      if email
        email.update_attributes!(address: email_address)
      else
        emails.build(kind: 'work', address: email_address)
        save
      end
    end
    phone = phones.detect{|p|p.kind == 'work'}
    if phone
      phone.update_attributes!(area_code: area_code, number: number, extension: extension)
    else
      phones.build(kind: 'work', area_code: area_code, number: number, extension: extension)
      save
    end
  end

  def generate_family_search
    ::MapReduce::FamilySearchForPerson.populate_for(self)
  end

  def set_ridp_for_paper_application(session_var)
    if user && session_var == 'paper'
      user.ridp_by_paper_application
      consumer_role&.move_identity_documents_to_verified
    end
  end

  %w[addresses emails phones].each do |association|
    define_method("person_#{association}=") do |array_attributes|
      assign(array_attributes, association.to_sym)
    end
  end

  # Creates a new Broker Agency Staff Role with given input params.
  #
  # @note This method may raise an exception if the Broker Agency Staff Role is not created successfully.
  #
  # @param [Hash] basr_params.
  #   The acceptable keys: :aasm_state, :benefit_sponsors_broker_agency_profile_id, :reason
  #   Currently, we only create Broker Agency Staff Role with benefit_sponsors_broker_agency_profile_id
  # @return [BrokerAgencyStaffRole] broker_agency_staff_role if the Broker Agency Staff Role is created successfully.
  def create_broker_agency_staff_role(basr_params)
    basr = broker_agency_staff_roles.build(
      {
        benefit_sponsors_broker_agency_profile_id: basr_params[:benefit_sponsors_broker_agency_profile_id]
      }
    )
    save!
    basr
  end

  # @method pending_basr_by_profile_id(profile_id)
  # Retrieves the first pending Broker Agency Staff Role (BASR) for a given broker agency profile ID.
  #
  # @param [BSON::ObjectId] profile_id The ID of the Broker Agency Profile for which to retrieve the pending BASR.
  #
  # @return [BrokerAgencyStaffRole, nil] Returns the first pending broker agency staff role for the given broker agency profile ID, or nil if no such role exists.
  #
  # @example Retrieve the first pending BASR for a given profile ID
  #   person.pending_basr_by_profile_id(profile_id) #=> BrokerAgencyStaffRole or nil
  def pending_basr_by_profile_id(profile_id)
    broker_agency_staff_roles.broker_agency_pending.by_profile_id(profile_id).first
  end

  # Returns the first verification type that matches 'VerificationType::ALIVE_STATUS'.
  # The result is memoized, so subsequent calls will return the previously computed value
  # without querying the database again.
  #
  # @return [VerificationType, nil] the first verification type that matches 'VerificationType::ALIVE_STATUS', or nil if no such verification type exists.
  def alive_status
    return @alive_status if defined? @alive_status

    @alive_status = verification_types.where(type_name: VerificationType::ALIVE_STATUS).first
  end

  # Returns the first verification type that matches 'VerificationType::AMERICAN_INDIAN_STATUS'.
  # The result is memoized, so subsequent calls will return the previously computed value
  # without querying the database again.
  #
  # @return [VerificationType, nil] the first verification type that matches 'VerificationType::AMERICAN_INDIAN_STATUS', or nil if no such verification type exists.
  def american_indian_status
    return @american_indian_status if defined? @american_indian_status

    @american_indian_status = verification_types.where(type_name: VerificationType::AMERICAN_INDIAN_STATUS).first
  end

  # In order to avoid adding another callback,
  # this method is used after consumer_role is created for person
  # 1.) Factories::EnrollmentFactory -> self.build_consumer_role
  #   - used for consumer sign-up
  # 2.) Family -> build_consumer_role
  #   - used when creating a family_member from the 'Manage Family' from a user's homepage
  # 3.) Insured::FamiliesHelper -> build_consumer_role
  #   - used as a failsafe in case any family_members are missing a consumer role
  # 4.) Operations::People::CreateOrUpdateConsumerRole -> create_consumer_role
  #   - used when the legacy ::FinancialAssistance::Operations::Families::CreateOrUpdateMember propagates an applicant to a family_member
  def build_demographics_group
    return unless EnrollRegistry.feature_enabled?(:alive_status)
    Operations::People::BuildDemographicsGroup.new.call(self)
  end

  # Returns a list of all active role names for the person.
  # This method caches the result to avoid recalculating the active roles on subsequent calls.
  #
  # @return [Array<String>] An array of strings representing the active roles.
  def all_active_role_names
    return @all_active_role_names if defined?(@all_active_role_names)

    @all_active_role_names = role_names_based_on_status_of_roles
  end

  private

  def changed_address_attributes
    addresses.collect do |address|
      address_changed_attributes = address.changed_attributes
      address_changed_attributes.merge!({:kind => address.kind})
    end
  end

  def changed_phone_attributes
    phones.collect do |phone|
      phone_changed_attributes = phone.changed_attributes
      phone_changed_attributes.merge!({:kind => phone.kind})
    end
  end

  def changed_email_attributes
    emails.collect do |email|
      email_changed_attributes = email.changed_attributes
      email_changed_attributes.merge!({:kind => email.kind})
    end
  end

  def changed_relationship_attributes
    person_relationships.collect do |person_relationship|
      person_relationship_changed_attributes = person_relationship.changed_attributes
      person_relationship_changed_attributes.merge!({:relative_id => person_relationship.relative_id})
    end
  end

  # Determines the active roles based on specific conditions for each role.
  # It utilizes a hash where each key is a role (localized string) and its value is a boolean
  # indicating whether the role is active or not. Only roles with true conditions are kept.
  #
  # @return [Array<String>] An array of strings representing the active roles.
  def role_names_based_on_status_of_roles
    {
      l10n('user_roles.assister') => assister_role.present?,
      l10n('user_roles.broker') => active_broker_role?,
      l10n('user_roles.broker_agency_staff') => has_active_broker_staff_role?,
      l10n('user_roles.consumer') => active_consumer_role?,
      l10n('user_roles.csr') => csr_role.present?,
      l10n('user_roles.employee') => has_active_employee_role?,
      l10n('user_roles.employer_staff') => has_active_employer_staff_role?,
      l10n('user_roles.general_agency_staff') => has_active_general_agency_staff_role?,
      l10n('user_roles.hbx_staff') => hbx_staff_role.present?,
      l10n('user_roles.resident') => active_resident_role?
    }.select { |_role, condition| condition }.keys
  end

  # Checks if the resident role is active.
  #
  # @return [Boolean] True if the resident role is present and active, false otherwise.
  def active_resident_role?
    resident_role.present? && is_resident_role_active?
  end

  # Checks if the consumer role is active.
  #
  # @return [Boolean] True if the consumer role is present and active, false otherwise.
  def active_consumer_role?
    consumer_role.present? && is_consumer_role_active?
  end

  # Checks if the broker role is active.
  #
  # @return [Boolean] True if the broker role is present and active, false otherwise.
  def active_broker_role?
    broker_role&.active?
  end

  def assign(collection, association)
    collection.each do |attributes|
      attributes.symbolize_keys!
      record = send(association).find_or_initialize_by(kind: attributes[:kind])
      record.assign_attributes(attributes)
    end
  end

  def is_only_one_individual_role_active?
    if self.is_consumer_role_active? && self.is_resident_role_active?
      self.errors.add(:base, "Resident role and Consumer role can't both be active at the same time.")
    end
    true
  end

  def create_inbox
    welcome_subject = "Welcome to #{site_short_name}"
    welcome_body_translation_key = if broker_role || broker_agency_staff_roles.present?
                                     "inbox.create_inbox_broker_message"
                                   else
                                     "inbox.create_inbox_normal_user_message"
                                   end
    welcome_body = sanitize_html(l10n(
      welcome_body_translation_key,
      site_short_name: site_short_name,
      state_name: site_state_name,
      contact_center_short_number: EnrollRegistry[:enroll_app].settings(:contact_center_short_number).item,
      contact_center_tty_number: contact_center_tty_number,
      contact_center_name: contact_center_name
    ))
    mailbox = Inbox.create(recipient: self)
    mailbox.messages.create(subject: welcome_subject, body: welcome_body, from: "#{site_short_name}")
  end

  def update_full_name
    full_name
  end

  def no_changing_my_user
    if self.persisted? && self.user_id_changed?
      old_user, new_user= self.user_id_change
      return if old_user.blank?
      if (old_user != new_user)
        errors.add(:base, "you may not change the user_id of a person once it has been set and saved")
      end
    end
  end

  # Verify basic date rules
  def date_functional_validations
    date_of_death_is_blank_or_past
    date_of_death_follows_date_of_birth
  end

  def date_of_death_is_blank_or_past
    return unless self.date_of_death.present?
    errors.add(:date_of_death, "future date: #{self.date_of_death} is invalid date of death") if TimeKeeper.date_of_record < self.date_of_death
  end

  def date_of_death_follows_date_of_birth
    return unless self.date_of_death.present? && self.dob.present?

    if self.date_of_death < self.dob
      errors.add(:date_of_death, "date of death cannot preceed date of birth")
      errors.add(:dob, "date of birth cannot follow date of death")
    end
  end

  def consumer_fields_validations
    return unless @is_consumer_role.to_s == 'true' && consumer_role.is_applying_coverage.to_s == 'true' #only check this for consumer flow.

    citizenship_validation


    self.errors.add(:base, "American Indian / Alaska Native status is required.") if indian_tribe_member.to_s.blank?
    native_american_validation if @indian_tribe_member && @us_citizen

    incarceration_validation
  end

  def native_american_validation
    if EnrollRegistry[:indian_alaskan_tribe_details].enabled?
      self.errors.add(:tribal_state, "required when native american / alaska native is selected") unless tribal_state.present?
      self.errors.add(:tribal_name, "cannot contain numbers") unless (tribal_name =~ /\d/).nil?
      self.errors.add(:tribal_name, "required when native american / alaska native is selected") if !tribal_name.present? && !FinancialAssistanceRegistry[:featured_tribes_selection].enabled?
    else
      self.errors.add(:tribal_id, "required when native american / alaska native is selected") unless tribal_id.present?
      self.errors.add(:tribal_id, "must be 9 digits") if tribal_id.present? && !tribal_id.match("[0-9]{9}")
    end
  end

  def citizenship_validation
    if @us_citizen.to_s.blank?
      self.errors.add(:base, "Citizenship status is required.")
    elsif @us_citizen == false && (@eligible_immigration_status.nil? && EnrollRegistry.feature_enabled?(:immigration_status_question_required))
      self.errors.add(:base, "Eligible immigration status is required.")
    elsif @us_citizen == true && @naturalized_citizen.nil?
      self.errors.add(:base, "Naturalized citizen is required.")
    end
  end

  def incarceration_validation
    self.errors.add(:base, "Incarceration status is required.") if is_incarcerated.to_s.blank?
  end

  # Mec check
  def mec_check_eligible?
    return true if self.mec_check_response.nil?
    mec_check_date.day != Date.today
  end
end

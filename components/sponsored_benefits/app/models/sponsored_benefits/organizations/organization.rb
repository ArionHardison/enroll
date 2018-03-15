# Parent model for any business, government agency, or other organized entity
module SponsoredBenefits
  module Organizations
    class Organization
      include Mongoid::Document
      include Mongoid::Timestamps

      ENTITY_KINDS =[
        :tax_exempt_organization,
        :c_corporation,
        :s_corporation,
        :partnership,
        :limited_liability_corporation,
        :limited_liability_partnership,
        :household_employer,
        :governmental_employer,
        :foreign_embassy_or_consulate,
        :health_insurance_exchange
      ]

      field :hbx_id, type: String

      # Registered legal name
      field :legal_name, type: String

      # Doing Business As (alternate name)
      field :dba, type: String

      # Business structure or entity type 
      field :entity_kind, type: Symbol


      # Association that enables organizational hierarchies.
      # Organizations may be stored in a tree, with a parent "agency" associated with one or 
      # more "divisions".  Defining one side of the association will automatically populate
      # the other.  For example:
      # org_a.divisions << org_b  # org_b.agency => org_a
      # org_x.agency = org_y      # org_y.divisions => [org_x]
      belongs_to  :agency, inverse_of: :divisions, counter_cache: true,
                  class_name: "SponsoredBenefits::Organizations::Organization"
       
      has_many    :divisions, inverse_of: :agency, autosave: true,
                  class_name: "SponsoredBenefits::Organizations::Organization"
        

      # PlanDesignOrganization (an Organization subclass) association enables an organization 
      # or its agent to model options and costs for different benefit scenarios.  This is managed through
      # two association types: HABTM to track access/permissions and OTM to track instances of plan_designs.
      # Example 1: a Broker agent may prepare one or more designs/quotes for an Employer.  
      # Under this scenario, the Broker's access is defined through plan_design_authors and reciprocal 
      # plan_design_subjects associations, and the broker owns a plan_design_organization instance for the 
      # Employer (plan_design_subject) that may be used for modeling purposes.
      # Example 2: an Employer may prepare one or more plan designs for future coverage.  
      # Under this scenario, the Employer is both the plan_design_author and the plan_design_subject
      has_and_belongs_to_many :plan_design_authors, inverse_of: :plan_design_subjects, autosave: true,
                              class_name: "SponsoredBenefits::Organizations::Organization"
        
      has_and_belongs_to_many :plan_design_subjects, inverse_of: :plan_design_authors, autosave: true,
                              class_name: "SponsoredBenefits::Organizations::Organization"
 
      has_many    :plan_design_organizations, inverse_of: :plan_design_organization,
                  class_name: "SponsoredBenefits::Organizations::PlanDesignOrganization"

      has_many    :plan_design_subject_organizations, inverse_of: :subject_organization,
                  class_name: "SponsoredBenefits::Organizations::PlanDesignOrganization"

        
      # Organizations with EmployerProfile and HbxProfile belong to a Site
      belongs_to  :site, inverse_of: :site_organizations, counter_cache: true,
                  class_name: "SponsoredBenefits::Site"

      belongs_to  :site_owner, inverse_of: :owner_organization,
                  class_name: "SponsoredBenefits::Site"

      embeds_many :office_locations, 
                  class_name: "SponsoredBenefits::Organizations::OfficeLocation", 
                  cascade_callbacks: true, validate: true

      embeds_many :profiles, 
                  class_name: "SponsoredBenefits::Organizations::Profile"

      # Only one benefit_sponsorship may be active at a time.  Enable many to support history tracking
      has_many    :benefit_sponsorships, counter_cache: true,
                  class_name: "SponsoredBenefits::BenefitSponsorships::BenefitSponsorship"


      # Use the Document model for managing any/all documents associated with Organization
      has_many :documents, class_name: "SponsoredBenefits::Documents::Document"

      validates_presence_of :legal_name, :site, :profiles

      before_save :generate_hbx_id

      index({ legal_name: 1 })
      index({ dba: 1 },   { sparse: true })
      index({ fein: 1 },  { unique: true, sparse: true })
      index({ :"profiles._type" => 1 }, { sparse: true })
      index({ :"profiles._benefit_sponsorship_id" => 1 }, { sparse: true })

      scope :hbx_profiles,            ->{ where(:"profiles._type" => /.*HbxProfile$/) }
      scope :employer_profiles,       ->{ where(:"profiles._type" => /.*EmployerProfile$/) }
      scope :broker_agency_profiles,  ->{ where(:"profiles._type" => /.*BrokerAgencyProfile$/) }
      scope :general_agency_profiles, ->{ where(:"profiles._type" => /.*GeneralAgencyProfile$/) }
      scope :issuer_profiles,         ->{ where(:"profiles._type" => /.*IssuerProfile$/) }

      scope :datatable_search, ->(query) { self.where({"$or" => ([{"legal_name" => Regexp.compile(Regexp.escape(query), true)}, {"fein" => Regexp.compile(Regexp.escape(query), true)}, {"hbx_id" => Regexp.compile(Regexp.escape(query), true)}])}) }


      # Strip non-numeric characters
      def fein=(new_fein)
        numeric_fein = new_fein.to_s.gsub(/\D/, '')
        write_attribute(:fein, numeric_fein)
        @fein = numeric_fein
      end

      def sponsor_benefits_for(profile, benefit_market)
        if profile.benefit_sponsorship_eligible?
          benefit_sponsorships.build(profile: profile, benefit_market: benefit_market)
        else
          raise SponsoredBenefits::Errors::BenefitSponsorShipIneligibleError, "profile #{profile} isn't eligible to sponsor benefits"
        end 
      end


      class << self
        def default_search_order
          [[:legal_name, 1]]
        end

        def search_hash(s_rex)
          search_rex = Regexp.compile(Regexp.escape(s_rex), true)
          {
            "$or" => ([
              {"legal_name" => search_rex},
              {"fein" => search_rex},
            ])
          }
        end

      end


      private

      def generate_hbx_id
        write_attribute(:hbx_id, SponsoredBenefits::Organizations::HbxIdGenerator.generate_organization_id) if hbx_id.blank?
      end


    end
  end
end

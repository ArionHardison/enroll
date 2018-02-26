module SponsoredBenefits
  module BenefitMarkets
    class AcaShopConfiguration
      include Mongoid::Document
      include Mongoid::Timestamps

      field :ee_ct_max,           as: :employee_count_max, type: Integer, default: 50
      field :ee_ratio_min,        as: :employee_participation_ratio_min, type: Float, default: 0.666
      field :ee_non_owner_ct_min, as: :employee_non_owner_count_min, type: Integer, default: 1

      field :er_contrib_pct_min,  as: :employer_contribution_pct_min, type: Integer, default: 75

      field :binder_due_dom, as: :binder_payment_due_day_of_month, type: Integer


      field :binder_due_dom, as: :open_enrollment_max, type: Integer


      def employee_participation_ratio_min=()
      end

    end
  end
end

# frozen_string_literal: true

module Operations
  module Migrations
    module TaxHouseholdGroups
      # This class copies the application_id to application_hbx_id for tax household groups
      class CopyApplicationIdToApplicationHbxId
        include Dry::Monads[:do, :result]

        # Initiates the process of copying application_id to application_hbx_id
        #
        # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
        def call
          families  = yield fetch_eligible_families
          result    = yield copy_data(families)

          Success(result)
        end

        private

        # Fetches families with tax household groups that have an application_id
        #
        # @return [Dry::Monads::Result::Success<Array<Family>>] A list of eligible families
        def fetch_eligible_families
          Success(Family.only(:family_members, :tax_household_groups).where(:'tax_household_groups.application_id'.exists => true))
        end

        # Copies application_id to application_hbx_id for each tax household group and logs the results in a CSV file
        #
        # @param families [Array<Family>] the families to process
        # @return [Dry::Monads::Result::Success<String>] A success message with the path to the report
        def copy_data(families)
          csv_file = "#{Rails.root}/copy_application_id_to_application_hbx_id_report.csv"

          CSV.open(csv_file, 'w', force_quotes: true) do |csv|
            csv << ['Person HBX ID', 'Tax Household Group HBX ID', 'Source', 'Application Hbx ID', 'Error']

            families.no_timeout.each do |family|
              primary = family.primary_person

              family.tax_household_groups.where(:application_id.exists => true).each do |thhg|
                next thhg if thhg.application_hbx_id.present?

                thhg.set(application_hbx_id: thhg.application_id, updated_at: Time.now.utc)
                csv << [primary.hbx_id, thhg.hbx_id, thhg.source, thhg.application_hbx_id, 'No Error']
              rescue StandardError => e
                csv << [primary.hbx_id, thhg.hbx_id, thhg.source, thhg.application_hbx_id, e.message]
              end
            end
          end

          Success(
            "Successfully populated application_hbx_id for all the tax household groups. Please check the report: #{csv_file} for more details."
          )
        end
      end
    end
  end
end

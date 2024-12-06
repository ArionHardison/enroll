# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'
require 'aca_entities/operations/encryption/decrypt'

module FinancialAssistance
  module Operations
    module Transfers
      module MedicaidGateway
        # This operation handles re-ingesting payloads from Medicaid Gateway to load missing referral activity data.
        class AccountTransferReingest
          include ::FinancialAssistance::MeCountyHelper
          include Dry::Monads[:result, :do, :try]

          # Perform the re-ingestion process for the given payload.
          #
          # @param [Hash] params The input parameters for the operation.
          # @option params [Hash] :family The family details containing applications and applicants.
          # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
          #   A successful result containing the updated application or a failure with an error message.
          def call(params)
            payload = yield load_data(params)
            application = yield find_application(payload)
            updates = yield fetch_updates(payload, application)
            application = yield store_updates(updates, application)

            Success(application)
          end

          private

          # Load and transform the payload into a stringified hash.
          #
          # @param [Hash] payload The payload to load and process.
          # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
          #   Success with the processed payload or Failure with an error message.
          def load_data(payload = {})
            stringified_payload = payload.to_h.deep_stringify_keys!
            Success(stringified_payload)
          rescue StandardError => e
            Failure("load_data #{e}")
          end

          # Find the application in the database using the transfer ID.
          #
          # @param [Hash] payload The payload containing the family and application data.
          # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
          #   Success with the found application or Failure if no/multiple applications are found.
          def find_application(payload)
            app_payload = payload["family"]['magi_medicaid_applications'].first
            applications = FinancialAssistance::Application.where(transfer_id: app_payload["transfer_id"])
            return Failure("Application with transfer id #{app_payload['transfer_id']} not found") unless applications.any?
            return Failure("Multiple applications found with transfer id #{app_payload['transfer_id']}") if applications.count > 1

            Success(applications.first)
          end

          # Fetch updates for missing referral activities from the payload.
          #
          # @param [Hash] payload The payload containing applicants and referral data.
          # @param [FinancialAssistance::Application] application The application to update.
          # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
          #   Success with the updates hash or Failure if applicant matching fails.
          def fetch_updates(payload, application)
            application_payload = payload["family"]['magi_medicaid_applications'].first
            applicants_payload = application_payload["applicants"]

            updates = {}
            applicants_payload.each do |applicant_hash|
              applicant, index = matched_applicant_for(applicant_hash, application)
              return Failure("Failed to match applicant") unless applicant

              updates["applicants.#{index}.transfer_referral_reason"] = applicant_hash['transfer_referral_reason']
            end

            Success(updates)
          end

          # Match an applicant from the payload to an application applicant.
          #
          # @param [Hash] applicant_hash The applicant data from the payload.
          # @param [FinancialAssistance::Application] application The application to match against.
          # @return [Array] Matched applicant and its index, or nil if not found.
          def matched_applicant_for(applicant_hash, application)
            application.applicants.each_with_index do |applicant, index|
              if applicant.dob == applicant_hash['demographic']['dob'].to_date &&
                 applicant.first_name.downcase == applicant_hash['name']['first_name'].downcase &&
                 applicant.last_name.downcase == applicant_hash['name']['last_name'].downcase

                return [applicant, index]
              end
            end
          end

          # Persist updates to the application.
          #
          # @param [Hash] updates The updates to apply to the application.
          # @param [FinancialAssistance::Application] application The application to update.
          # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
          #   Success with the updated application or Failure with an error message.
          def store_updates(updates, application)
            FinancialAssistance::Application.collection.update_one(
              { _id: application.id },
              { "$set" => updates }
            )

            Success(application)
          rescue Mongoid::Errors::MongoidError => e
            Failure("Mongoid error: #{e.message}")
          rescue Mongo::Error => e
            Failure("MongoDB error: #{e.message}")
          rescue StandardError => e
            Failure("An unexpected error occurred: #{e.message}")
          end
        end
      end
    end
  end
end

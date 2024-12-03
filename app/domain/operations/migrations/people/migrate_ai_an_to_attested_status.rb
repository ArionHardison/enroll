# frozen_string_literal: true

module Operations
  module Migrations
    module People
      # This migration updates the 'American Indian Status' verification type
      # fields on People, moving their state from 'outstanding', 'review',
      # 'pending', 'unverified', and 'rejected' to 'attested'.
      #
      # @note A detailed report can be generated listing affected people along with
      #   verification type details where negative default states were previously stored.
      class MigrateAiAnToAttestedStatus
        include Dry::Monads[:do, :result]

        MODE = %i[migrate_data report].freeze

        # Initializes the operation with options to update `American Indian Status`
        # verification types to `attested`.
        #
        # @param [Hash] params Options to control the operation.
        # @option params [Symbol] :mode The mode of operation, must be one of `:migrate_data` or `:report`.
        # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
        #   Success with the result of operation, or Failure with an error message.
        def call(params)
          values = yield validate(params)
          people = yield fetch_impacted_people
          result = yield migrate(people, values[:mode])

          Success(result)
        end

        private

        # Validates the parameters passed.
        #
        # @param [Hash] params The parameters to validate.
        # @option params [Symbol] :mode The operation mode. Defaults to `:report` if not provided.
        # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
        #   Success with validated parameters, or Failure with an error message if validation fails.
        def validate(params)
          params[:mode] = :report unless params[:mode].present?
          return Failure("Please pass a valid argument. Must be one of: #{MODE.join(', ')}") unless MODE.include?(params[:mode])

          Success(params)
        end

        def fetch_impacted_people
          people = Person.where("verification_types.type_name": VerificationType::AMERICAN_INDIAN_STATUS)

          Success(people)
        end

        def filename(mode)
          "migrate_ai_an_to_attested_status_#{mode}_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.csv"
        end

        # Initializes a CSV file with headers for reporting impacted enrollments depending on the mode.
        #
        # @param [Symbol] mode: The operation mode.
        # @return [void]
        def initialize_csv(mode)
          CSV.open(filename(mode), "w") do |csv|
            csv << if mode == :migrate_data
                     ['Person hbx_id', 'VerificationType name', 'VerificationType inactive', 'Original VerificationType validation_status', 'Original VerificationType update_reason',
                      'Original VerificationType Due Date', 'Updated VerificationType validation_status', 'Updated VerificationType update_reason', 'Updated VerificationType due_date',
                      'VerificationType TypeHistoryElement action', 'VerificationType TypeHistoryElement modifier', 'VerificationType TypeHistoryElement update_reason',
                      'VerificationType TypeHistoryElement event_response_record_id', 'VerificationType TypeHistoryElement event_request_record_id',
                      'VerificationType TypeHistoryElement from_validation_status', 'VerificationType TypeHistoryElement to_validation_status', 'Result']
                   else
                     ['Person hbx_id', 'VerificationType name', 'VerificationType inactive', 'VerificationType validation_status', 'VerificationType update_reason', 'VerificationType due_date',
                      'VerificationType TypeHistoryElement action', 'VerificationType TypeHistoryElement modifier', 'VerificationType TypeHistoryElement update_reason', 'VerificationType TypeHistoryElement event_response_record_id',
                      'VerificationType TypeHistoryElement event_request_record_id', 'VerificationType TypeHistoryElement from_validation_status', 'VerificationType TypeHistoryElement to_validation_status', 'Result']
                   end
          end
        end

        # Appends a row of data to the CSV file.
        #
        # @param [Array<String>] row The data to append as a row in the CSV.
        # @param [Symbol] mode The operation mode.
        # @return [void]
        def append_csv_row(row, mode)
          CSV.open(filename(mode), 'a') do |csv|
            csv << row
          end
        end

        # Generates a data row for a given person to be written to the CSV file depending on the mode.
        #
        # @param [Person] person: The person to process.
        # @param [VerificationType] verification_type: The verification type to process.
        # @param [Symbol] mode: The operation mode.
        # @param [String] result: The result of the operation.
        def data_row(person, verification_type, mode, result)
          last_type_history_element = verification_type.type_history_elements&.last
          mode == :migrate_data ? migrate_data_row(person, verification_type, last_type_history_element, result) : default_row(person, verification_type, last_type_history_element)
        end

        def migrate_data_row(person, verification_type, last_type_history_element, result)
          history_track = verification_type.history_tracks&.last&.original
          [
            person.hbx_id,
            verification_type.type_name,
            verification_type.inactive,
            history_track&.dig(:validation_status),
            history_track&.dig(:update_reason),
            history_track&.dig(:due_date),
            verification_type.validation_status,
            verification_type.update_reason,
            verification_type.due_date,
            last_type_history_element&.action,
            last_type_history_element&.modifier,
            last_type_history_element&.update_reason,
            last_type_history_element&.event_response_record_id,
            last_type_history_element&.event_request_record_id,
            last_type_history_element&.from_validation_status,
            last_type_history_element&.to_validation_status,
            result
          ]
        end

        def default_row(person, verification_type, last_type_history_element)
          [
            person.hbx_id,
            verification_type.type_name,
            verification_type.inactive,
            verification_type.validation_status,
            verification_type.update_reason,
            verification_type.due_date,
            last_type_history_element&.action,
            last_type_history_element&.modifier,
            last_type_history_element&.update_reason,
            last_type_history_element&.event_response_record_id,
            last_type_history_element&.event_request_record_id,
            last_type_history_element&.from_validation_status,
            last_type_history_element&.to_validation_status
          ]
        end

        # Updates impacted cases, records fixes, or exports impacted case data.
        #
        # @param [Array<Person>] people: The list of people to process.
        # @param [Symbol] mode The operation mode: either `:migrate_data` or `:report`.
        # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
        # Success with the result of processing, or Failure with an error message if an error occurs.
        def migrate(people, mode)
          initialize_csv(mode)
          people.each do |person|

            american_indian_status = person.american_indian_status
            next unless american_indian_status
            next if VerificationType::SELF_ATTESTATION_STATES.include?(american_indian_status.validation_status)

            result = update_person(american_indian_status) if mode == :migrate_data

            data = data_row(person, american_indian_status, mode, result)
            append_csv_row(data, mode)
          end

          Success(true)
        rescue StandardError => e
          Failure(e.message)
        end

        def update_person(verification_type)
          current_validation = verification_type.validation_status
          verification_type.update_attributes!(validation_status: "attested", update_reason: "Self Attest American Indian Status", due_date: nil)
          verification_type.add_type_history_element(action: 'Migrate to attested', modifier: 'System', update_reason: 'Policy change to accept self-attestation of American Indian status', event_response_record_id: nil,
                                                     event_request_record_id: nil, from_validation_status: current_validation, to_validation_status: 'attested')
          'Success'
        rescue StandardError => e
          "Error: #{e.message}"
        end
      end
    end
  end
end

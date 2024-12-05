# frozen_string_literal: true

module Operations
  # This operation is responsible for deleting Hbx Profile messages.
  class DeleteHbxProfileMessages
    include Dry::Monads[:do, :result]

    def call
      all_eligible_messages        = yield fetch_hbx_profile_messages
      csv_file                     = yield generate_csv_file(all_eligible_messages)
      _delete_hbx_profile_messages = yield delete_hbx_profile_messages(all_eligible_messages)

      Success(csv_file)
    end

    def fetch_hbx_profile_messages
      aca_state_abbreviation = EnrollRegistry[:enroll_app].setting(:state_abbreviation).item
      all_eligible_messages = HbxProfile.find_by_state_abbreviation(aca_state_abbreviation).inbox.messages
      return Failure("No messages found") unless all_eligible_messages.present?
      Success(all_eligible_messages)
    end

    def generate_csv_file(all_eligible_messages)
      date = Time.now.strftime('%Y_%m_%d')
      csv_file_name = "#{Rails.root}/deleted_hbx_profile_messages_report_#{date}.csv"
      CSV.open(csv_file_name, 'w', force_quotes: true) do |csv|
        csv << ['Message bson ID', 'Created At', 'Attributes']

        all_eligible_messages.each do |msg|
          csv << [msg.id, msg.created_at.strftime('%Y-%m-%d %H:%M:%S'), msg.attributes]
        end
      end
      Success(csv_file_name)
    end

    def delete_hbx_profile_messages(all_eligible_messages)
      all_eligible_messages.delete_all
      Success("Messages deleted successfully")
    end
  end
end
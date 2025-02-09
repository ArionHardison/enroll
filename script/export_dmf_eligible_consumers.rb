# frozen_string_literal: true

# This script generates a CSV report which lists all consumers eligible to be included in a DMF call

# To run this script
# bundle exec rails runner script/export_dmf_eligible_consumers.rb

require "#{Rails.root}/app/domain/operations/families/verifications/dmf_determination/dmf_utils.rb"
include ::Operations::Families::Verifications::DmfDetermination::DmfUtils # rubocop:disable Style/MixinUsage

if EnrollRegistry.feature_enabled?(:alive_status)
  csv_headers = [
    "Family Hbx ID",
    "Person Hbx ID",
    "Person First Name",
    "Person Last Name",
    "Has SSN?",
    "Has Valid SSN?",
    "Has Eligible Enrollment?",
    "Enrollment Hbx ID",
    "Enrollment Type",
    "Enrollment Status"
  ].freeze

  dmf_eligibile_members = []

  Family.all.no_timeout.each do |family|
    family.family_members.each do |member|
      person = member.person

      next unless person&.consumer_role.present?

      eligibility_states = member_dmf_determination_eligible_enrollments(member, family)
      ssn_present = person&.ssn&.present?
      # is_ssn_composition_correct? will return 'nil' if the composition is correct
      valid_ssn = (ssn_present && person&.is_ssn_composition_correct?.nil?)
      has_eligible_enrollment = eligibility_states.present?

      consumer_hash = {
        family_hbx_id: family.hbx_assigned_id,
        person_hbx_id: person.hbx_id,
        person_first_name: person.first_name,
        person_last_name: person.last_name,
        has_ssn: ssn_present,
        has_valid_ssn: valid_ssn,
        has_eligible_enrollment: has_eligible_enrollment
      }

      if valid_ssn & has_eligible_enrollment
        enrollment_types = eligibility_states.map { |state| state.eligibility_item_key.split('_')[0] }.join(', ')
        enrollment_hbx_id, enrollment_status = extract_enrollment_info(family, member.hbx_id)
        addtl_enrollment_info = {
          enrollment_hbx_id: enrollment_hbx_id,
          enrollment_types: enrollment_types,
          enrollment_status: enrollment_status
        }

        consumer_hash.merge!(addtl_enrollment_info)
      end

      dmf_eligibile_members << consumer_hash
    end
  rescue StandardError => e
    p "Error processing family with hbx_id #{family.hbx_assigned_id} due to #{e}"
  end

  p "found #{dmf_eligibile_members.size} dmf-eligible consumers"  unless Rails.env.test?

  CSV.open("export_dmf_eligible_consumers_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}_#{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%H:%M:%S')}.csv", "w") do |csv|
    csv << csv_headers
    consumers_counter = 0

    puts "Processing dmf-eligible consumers" unless Rails.env.test?

    dmf_eligibile_members.each do |consumer_hash|
      consumers_counter += 1
      puts "Processing person with hbx_id #{consumer_hash[:person_hbx_id]} and index at #{consumers_counter}" unless Rails.env.test?

      csv << [
        consumer_hash[:family_hbx_id],
        consumer_hash[:person_hbx_id],
        consumer_hash[:person_first_name],
        consumer_hash[:person_last_name],
        consumer_hash[:has_ssn],
        consumer_hash[:has_valid_ssn],
        consumer_hash[:has_eligible_enrollment],
        consumer_hash[:enrollment_hbx_id],
        consumer_hash[:enrollment_types],
        consumer_hash[:enrollment_status]
      ]
    end
    p "processed #{consumers_counter} consumers"  unless Rails.env.test?
  end
else
  p "alive_status feature is not active for this environment"
end

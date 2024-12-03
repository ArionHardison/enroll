# frozen_string_literal: true

# This script identifies and updates the 'American Indian Status' verification type
# fields in People, moving their state from 'outstanding', 'review', 'pending', 'unverified',
# and 'rejected' to 'attested'.
#
# The script operates in two modes:
# 1. `report`: Generates a report of people with 'American Indian Status' verification type fields in the aforementioned states.
# 2. `migrate_data`: Updates the 'American Indian Status' verification types.
#
# @example Run in report mode to identify people with negative American Indian Status states
#   bundle exec rails runner script/people/migrate_ai_an_to_attested_status.rb report
#
# @example Run in migrate_data mode to update the American Indian Status verification types to attested
#   bundle exec rails runner script/people/migrate_ai_an_to_attested_status.rb migrate_data

mode = ARGV[0]

# Validate mode and provide usage guidance
unless mode
  puts <<~USAGE
    ************************************************************
    Please provide a valid argument. Must be one of: report, migrate_data
    To generate a report of People with negative American Indian Status states, run:
      bundle exec rails runner script/migrate_ai_an_to_attested_status.rb report
    To update the American Indian Status verification types to attested, run:
      bundle exec rails runner script/migrate_ai_an_to_attested_status.rb migrate_data
    ************************************************************
  USAGE
  exit
end

elapsed_time = Caches::BenchmarkCache.with_benchmark do
  # Execute the migration operation based on the mode
  migration = Operations::Migrations::People::MigrateAiAnToAttestedStatus.new
  result = migration.call(mode: mode.to_sym)

  if result.success?
    puts <<~SUCCESS
      ************************************************************
      Operation completed successfully.
      A report CSV file has been generated with the name format: migrate_ai_an_to_attested_status_MODE_YYYY_MM_DD.csv in the Rails root directory.
      Please copy the file to your preferred location and attach it to the ticket.
      ************************************************************
    SUCCESS
  else
    puts result.failure
  end
end

# End timing and calculate elapsed time
puts "********** FINISHED in #{elapsed_time.ceil} seconds - Script to migrate User's American Indian statuses to attested when in outstanding states. **********"

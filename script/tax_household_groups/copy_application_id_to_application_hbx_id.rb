# frozen_string_literal: true

# This script triggers the operation to copy the application id to the application hbx id for all the tax household groups.
#
# Command to trigger the script:
#   CLIENT=me bundle exec rails runner script/tax_household_groups/copy_application_id_to_application_hbx_id.rb

p '********** STARTING - Script to copy the application id to the application hbx id for eligible tax household groups. **********'

elapsed_time = Caches::BenchmarkCache.with_benchmark do
  # Calls the operation to copy the application id to the application hbx id for all the tax household groups.
  # If the job is successful, it logs the success message and instructions.
  # If the job fails, it logs the failure message.
  #
  # @return [void]
  result = ::Operations::Migrations::TaxHouseholdGroups::CopyApplicationIdToApplicationHbxId.new.call

  if result.success?
    puts result.success
  else
    puts result.failure
  end
end

p "********** FINISHED in #{elapsed_time.ceil} seconds - Script to copy the application id to the application hbx id for eligible tax household groups. **********"

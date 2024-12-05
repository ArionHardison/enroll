# frozen_string_literal: true

# This script deletes HBX Profile messages.
# Command to trigger the script:
#   CLIENT=me bundle exec rails runner script/delete_hbx_profile_inbox_messages.rb

result = ::Operations::DeleteHbxProfileMessages.new.call

if result.success?
  p "Report generated: #{result.success}"
else
  p result.failure
end
# frozen_string_literal: true

Given(/^an IVL Broker Agency exists$/) do
  broker_name = "IVL Broker Agency"
  broker_agency_organization broker_name, legal_name: broker_name, dba: broker_name

  broker_agency_profile(broker_name).update_attributes!(aasm_state: 'is_approved', market_kind: 'individual')
end

And(/Individual clicks on the Help Me Sign Up link?/) do
  find("#help_with_plan_shopping_btn").click
end

And(/Individual clicks on the Help from an Expert link?/) do
  path = benefit_sponsors.staff_index_profiles_broker_agencies_broker_agency_profiles_path
  find("a[href='#{path}']").click
end

And(/Individual selects a broker?/) do
  find(".broker_select_button").click
end

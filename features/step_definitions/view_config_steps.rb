# frozen_string_literal: true

Given(/^the (.*) is on the Main Page$/) do |_type|
  visit exchanges_hbx_profiles_root_path
  expect(current_path).to eq exchanges_hbx_profiles_root_path
end

Given(/^the user with a (.*?) role(?: with (.*?) subrole)? updates permisssions to time travel$/) do |type, subrole|
  user = admin(subrole)
  user.person.hbx_staff_role.permission.update_attributes(can_submit_time_travel_request: true)
end

Then(/^the user will see the Config tab$/) do
  find('.dropdown-toggle', :text => "Admin").click
  expect(page).to have_content('Config')
end

Then(/^the user will not see the Config tab$/) do
  find('.dropdown-toggle', :text => "Admin").click
  expect(page).to_not have_content('Config')
end

Given(/^the user goes to the Config Page$/) do
  find('.dropdown-toggle', :text => "Admin").click
  click_link 'Config'
  expect(page).to have_content('Configuration')
end

Then(/^the user will not see the Time Tavel option$/) do
  expect(page).to have_button('Set Current Date', disabled: true)
end

Then(/^the user will see the Time Tavel option$/) do
  expect(page).to have_button('Set Current Date', disabled: false)
end

And(/^the user should see Announcements button/) do
  expect(page).to have_css('.interaction-click-control-announcements')
end

And(/^the user will clicks on Announcements page/) do
  find('.interaction-click-control-announcements').click
end

And(/^the user should see Current Announcements text/) do
  expect(page).to have_content('Current Announcements')
end


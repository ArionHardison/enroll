# frozen_string_literal: true

Given(/^a person exists with a Broker user$/) do
  @broker = FactoryBot.create(
    :person,
    :with_broker_role,
    first_name: 'Broker',
    last_name: 'Person'
  )

  FactoryBot.create(:user, person: @broker)
end

And(/^the Broker user logs into their account$/) do
  login_as(@broker.user, scope: :user)
end

And(/^this person has an approved broker role and broker agency profile$/) do
  @broker_role = FactoryBot.create(:broker_role, person: @broker)
  site = FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, site_key: ::EnrollRegistry[:enroll_app].settings(:site_key).item)
  broker_agency_organization = FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, legal_name: 'First Legal Name', site: site)
  @broker_agency_profile = broker_agency_organization.broker_agency_profile
  @broker_agency_profile.set(primary_broker_role_id: @broker_role.id)
  @broker_role.set(benefit_sponsors_broker_agency_profile_id: @broker_agency_profile.id)
  @broker_role.approve!
  @broker.create_broker_agency_staff_role(benefit_sponsors_broker_agency_profile_id: @broker_agency_profile.id).broker_agency_accept!
  @broker_agency_profile.approve! if @broker_agency_profile.may_approve?
end

And(/^the consumer has selected the broker to represent them$/) do
  @broker_agency_profile.set(market_kind: 'individual')
  @broker_agency_account = FactoryBot.build(:benefit_sponsors_accounts_broker_agency_account, broker_agency_profile: @broker_agency_profile, is_active: true, writing_agent: @broker_role)
  @consumer.person.primary_family.broker_agency_accounts << @broker_agency_account
end

And(/^.+ clicks on the Broker Agency Portal button/) do
  page.find(:css, "a[href='/benefit_sponsors/profiles/registrations/new?portal=true&profile_type=broker_agency']").click
end

And(/^.+ clicks on the assigned user/) do
  # Clicks the first user link in the Broker Families Datatable
  page.find(:css, "a[href='/exchanges/agents/resume_enrollment?person_id=#{@consumer.person.id}']").click
end

And(/^the Broker user clicks on the Documents tab from the user's side navigation$/) do
  page.find('.interaction-click-control-verifications').click
end
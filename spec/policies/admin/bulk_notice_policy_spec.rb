# frozen_string_literal: true

require 'rails_helper'

describe Admin::BulkNoticePolicy, dbclean: :after_each do
  let(:user){FactoryBot.create(:user)}
  let(:person){FactoryBot.create(:person, user: user, broker_agency_staff_roles: [], broker_role: nil, hbx_staff_role: nil)}
  let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile) }
  let(:audience) { broker_agency_profile.organization }
  let(:bulk_notice) { FactoryBot.create :bulk_notice, user: user, audience_type: 'employees', audience_ids: [audience.id.to_s]}
  let(:policy){ Admin::BulkNoticePolicy.new(user, bulk_notice) }

  context 'access to download document' do

    it 'hbx staff role' do
      FactoryBot.create(:hbx_staff_role, person: person)
      expect(policy.can_download_document?).to be true
    end

    it 'no role' do
      expect(policy.can_download_document?).not_to be true
    end

    it 'broker matches broker agency profile' do
      FactoryBot.create(:broker_role, person: person, broker_agency_profile: broker_agency_profile, aasm_state: 'active')
      expect(policy.can_download_document?).to be true
    end

    it 'broker does not match broker agency profile' do
      FactoryBot.create(:broker_role, person: person, broker_agency_profile: FactoryBot.create(:broker_agency_profile), aasm_state: 'active')
      expect(policy.can_download_document?).not_to be true
    end

    it 'broker_agency_staff_roles can see broker agency profile' do
      FactoryBot.create(:broker_agency_staff_role, person: person, broker_agency_profile_id: broker_agency_profile.id,broker_agency_profile: broker_agency_profile, aasm_state: 'active')
      expect(policy.can_download_document?).to be true
    end

    it 'broker_agency_staff_roles present but do not match with audience ids' do
      FactoryBot.create(:broker_agency_staff_role, person: person, broker_agency_profile: FactoryBot.create(:broker_agency_profile), aasm_state: 'active')
      expect(policy.can_download_document?).not_to be true
    end

    it 'broker_agency_staff_roles match with audience ids' do
      FactoryBot.create(:broker_agency_staff_role, broker_agency_profile_id: broker_agency_profile.id, person: person, broker_agency_profile: broker_agency_profile, aasm_state: 'active')
      FactoryBot.create(:broker_agency_staff_role, broker_agency_profile_id: broker_agency_profile.id, person: person, broker_agency_profile: FactoryBot.create(:broker_agency_profile), aasm_state: 'active')
      expect(policy.can_download_document?).to be true
    end

    it 'broker_agency_staff_roles do not match with audience ids' do
      FactoryBot.create(:broker_agency_staff_role, person: person, broker_agency_profile: broker_agency_profile, aasm_state: 'is_applicant')
      FactoryBot.create(:broker_agency_staff_role, person: person, broker_agency_profile: FactoryBot.create(:broker_agency_profile), aasm_state: 'active')
      expect(policy.can_download_document?).to be false
    end
  end
end

# frozen_string_literal: true

# spec/policies/evidence_policy_spec.rb
require 'rails_helper'

RSpec.describe Eligibilities::EvidencePolicy, type: :policy do
  let(:policy) { described_class.new(user, record) }
  let!(:person) { FactoryBot.create(:person, :with_consumer_role) }
  let(:consumer_role) { person.consumer_role }
  let!(:associated_user) {FactoryBot.create(:user, :person => person)}
  let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person) }
  let!(:family_member) { family.family_members.first }
  let!(:application) do
    FactoryBot.create(
      :application,
      family_id: family.id,
      aasm_state: 'determined',
      assistance_year: TimeKeeper.date_of_record.year,
      effective_date: Date.today
    )
  end

  let!(:applicant) do
    applicant = FactoryBot.create(:financial_assistance_applicant,
                                  application: application,
                                  is_primary_applicant: true,
                                  ssn: person.ssn,
                                  dob: person.dob,
                                  first_name: person.first_name,
                                  last_name: person.last_name,
                                  gender: person.gender,
                                  person_hbx_id: person.hbx_id,
                                  family_member_id: family_member.id)
    applicant
  end

  let(:record) do
    applicant.create_esi_evidence(
      key: :esi_mec,
      title: 'Esi',
      aasm_state: 'pending',
      due_on: nil,
      verification_outstanding: false,
      is_satisfied: true
    )
  end

  context 'admin user' do
    let!(:admin_person) { FactoryBot.create(:person, :with_hbx_staff_role) }
    let!(:admin_user) {FactoryBot.create(:user, :with_hbx_staff_role, :person => admin_person)}
    let!(:update_admin) { admin_person.hbx_staff_role.update_attributes(permission_id: permission.id) }
    let(:user) { admin_user }

    context 'with permission' do
      let!(:permission) { FactoryBot.create(:permission, :super_admin) }

      context '#can_upload?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_upload?).to be_truthy
        end
      end

      context '#can_download?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_download?).to be_truthy
        end
      end

      context '#can_destroy?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_destroy?).to be_truthy
        end
      end

      context '#allowed_to_modify?' do
        context 'when the user has the modify_family permission' do

          it 'returns true' do
            expect(policy.send(:allowed_to_modify?)).to be true
          end
        end
      end

      context '#extend_due_date?' do
        it 'returns the result of #extend_due_date?' do
          expect(policy.extend_due_date?).to be_truthy
        end
      end

      context '#fdsh_hub_request?' do
        it 'returns true' do
          expect(policy.fdsh_hub_request?).to be_truthy
        end
      end
    end

    context 'without permission' do
      let!(:permission) { FactoryBot.create(:permission, :developer) }

      context '#can_upload?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_upload?).to be_falsey
        end
      end

      context '#can_download?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_download?).to be_falsey
        end
      end

      context '#can_destroy?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_destroy?).to be_falsey
        end
      end

      context '#allowed_to_modify?' do
        context 'when the user has the modify_family permission' do

          it 'returns true' do
            expect(policy.send(:allowed_to_modify?)).to be false
          end
        end
      end

      context '#extend_due_date?' do
        it 'returns the result of #extend_due_date?' do
          expect(policy.extend_due_date?).to be_falsey
        end
      end

      context '#fdsh_hub_request?' do
        it 'returns false' do
          expect(policy.fdsh_hub_request?).to be_falsey
        end
      end
    end
  end

  context 'record user' do
    let(:user) { associated_user }

    context '#can_upload?' do
      it 'returns the result of #allowed_to_modify?' do
        expect(policy.can_upload?).to be_truthy
      end
    end

    context '#can_download?' do
      it 'returns the result of #allowed_to_modify?' do
        expect(policy.can_download?).to be_truthy
      end
    end

    context '#can_destroy?' do
      it 'returns the result of #allowed_to_modify?' do
        expect(policy.can_destroy?).to be_truthy
      end
    end

    context '#allowed_to_modify?' do
      context 'when the user has the modify_family permission' do

        it 'returns true' do
          expect(policy.send(:allowed_to_modify?)).to be true
        end
      end
    end

    context '#extend_due_date?' do
      it 'returns the result of #extend_due_date?' do
        expect(policy.extend_due_date?).to be_falsey
      end
    end

    context '#fdsh_hub_request?' do
      it 'returns false' do
        expect(policy.fdsh_hub_request?).to be_falsey
      end
    end
  end

  context 'unauthorized user' do
    let!(:fake_person) { FactoryBot.create(:person, :with_consumer_role) }
    let!(:fake_user) {FactoryBot.create(:user, :person => fake_person)}
    let!(:fake_family) { FactoryBot.create(:family, :with_primary_family_member, person: fake_person) }
    let!(:fake_family_member) { fake_family.family_members.first }
    let(:user) { fake_user }

    context '#can_upload?' do
      it 'returns the result of #allowed_to_modify?' do
        expect(policy.can_upload?).to be_falsey
      end
    end

    context '#can_download?' do
      it 'returns the result of #allowed_to_modify?' do
        expect(policy.can_download?).to be_falsey
      end
    end

    context '#can_destroy?' do
      it 'returns the result of #allowed_to_modify?' do
        expect(policy.can_destroy?).to be_falsey
      end
    end

    context '#allowed_to_modify?' do
      context 'when the user has the modify_family permission' do

        it 'returns true' do
          expect(policy.send(:allowed_to_modify?)).to be false
        end
      end
    end

    context '#extend_due_date?' do
      it 'returns the result of #extend_due_date?' do
        expect(policy.extend_due_date?).to be_falsey
      end
    end

    context '#fdsh_hub_request?' do
      it 'returns false' do
        expect(policy.fdsh_hub_request?).to be_falsey
      end
    end
  end

  context 'broker logged in' do
    let(:market_kind) { 'both' }
    let(:broker_user) { FactoryBot.create(:user, :person => writing_agent.person, roles: ['broker_role', 'broker_agency_staff_role']) }
    let(:broker_person) { FactoryBot.create(:person, :with_broker_role) }
    let(:broker_agency_profile) { FactoryBot.build(:benefit_sponsors_organizations_broker_agency_profile)}
    let(:writing_agent)         { FactoryBot.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active') }

    let(:site) do
      FactoryBot.create(
        :benefit_sponsors_site,
        :with_benefit_market,
        :as_hbx_profile,
        site_key: ::EnrollRegistry[:enroll_app].settings(:site_key).item
      )
    end

    let(:broker_agency_organization) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site) }
    let(:assister)  do
      assister = FactoryBot.build(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, npn: "SMECDOA00")
      assister.save(validate: false)
      assister
    end

    let(:user) { broker_user }

    context 'hired by family' do
      let(:baa_active) { true }
      let(:broker_agency_account) do
        family.broker_agency_accounts.create!(
          benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id,
          writing_agent_id: writing_agent.id,
          is_active: baa_active,
          start_on: TimeKeeper.date_of_record
        )
      end

      before do
        writing_agent.update_attributes!(benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active')
        broker_person.create_broker_agency_staff_role(
          benefit_sponsors_broker_agency_profile_id: writing_agent.benefit_sponsors_broker_agency_profile_id
        )
        broker_agency_profile.update_attributes!(primary_broker_role_id: writing_agent.id, market_kind: market_kind)
        broker_agency_account
      end

      before(:each) do
        family.broker_agency_accounts << BenefitSponsors::Accounts::BrokerAgencyAccount.new(benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id,
                                                                                            writing_agent_id: writing_agent.id,
                                                                                            start_on: Time.now,
                                                                                            is_active: true)
        family.reload
      end


      context '#can_upload?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_upload?).to be_truthy
        end
      end

      context '#can_download?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_download?).to be_truthy
        end
      end

      context '#can_destroy?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_destroy?).to be_truthy
        end
      end

      context '#extend_due_date?' do
        it 'returns the result of #extend_due_date?' do
          expect(policy.extend_due_date?).to be_falsey
        end
      end

      context '#fdsh_hub_request?' do
        it 'returns false' do
          expect(policy.fdsh_hub_request?).to be_falsey
        end
      end
    end

    context 'not hired by family' do
      context '#can_upload?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_upload?).to be_falsey
        end
      end

      context '#can_download?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_download?).to be_falsey
        end
      end

      context '#can_destroy?' do
        it 'returns the result of #allowed_to_modify?' do
          expect(policy.can_destroy?).to be_falsey
        end
      end

      context '#extend_due_date?' do
        it 'returns the result of extend_due_date?' do
          expect(policy.extend_due_date?).to be_falsey
        end
      end

      context '#fdsh_hub_request?' do
        it 'returns false' do
          expect(policy.fdsh_hub_request?).to be_falsey
        end
      end
    end
  end

end
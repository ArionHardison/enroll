# frozen_string_literal: true

require 'rails_helper'

describe BulkNoticeWorker do
  describe "#peform_async" do

    context "with employees as the audience type" do
      let(:profile) { FactoryBot.create :benefit_sponsors_organizations_aca_shop_dc_employer_profile }
      let(:audience) { profile.organization }
      let!(:user) { FactoryBot.create(:user, :with_hbx_staff_role) }
      let(:bulk_notice) { FactoryBot.create :bulk_notice, user: user, audience_type: 'employees', audience_ids: [audience.id.to_s]}

      before { BulkNoticeWorker.perform_async(audience.id.to_s, bulk_notice.id.to_s) }

      it 'delievered a message with results' do
        skip("is implemented but waiting")
      end

      it 'generates a result for each employee (audience_member)' do
        skip("is implemented but waiting")
      end
    end

    context '.fetch_resource' do
      let(:organization) { employer_profile.organization }
      let(:employer_profile) { FactoryBot.create :benefit_sponsors_organizations_aca_shop_dc_employer_profile }
      let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile) }
      let(:broker_person) { broker_agency_profile.primary_broker_role.person }
      let(:general_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_general_agency_profile, organization: organization) }

      it 'should return employer profile' do
        expect(subject.fetch_resource(employer_profile.organization, 'employer')).to eq employer_profile
      end

      it 'should return general agency profile' do
        expect(subject.fetch_resource(general_agency_profile.organization, 'general_agency')).to eq general_agency_profile
      end

      it 'should return primary broker person' do
        expect(subject.fetch_resource(broker_agency_profile.organization, 'broker_agency')).to eq broker_agency_profile
      end
    end

    context '.fetch_params' do
      let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile) }
      let(:audience) { broker_agency_profile.organization }
      let!(:user) { FactoryBot.create(:user, :with_hbx_staff_role) }
      let(:bulk_notice) { FactoryBot.create :bulk_notice, user: user, audience_type: 'employees', audience_ids: [audience.id.to_s]}

      it 'should include model_id' do
        expect(subject.fetch_params(bulk_notice).keys).to include :document
      end

      it 'should not include model_id' do
        expect(subject.fetch_params(bulk_notice).keys).not_to include :model_id
      end

      it 'should not include model_klass' do
        expect(subject.fetch_params(bulk_notice).keys).not_to include :model_klass
      end
    end
  end
end

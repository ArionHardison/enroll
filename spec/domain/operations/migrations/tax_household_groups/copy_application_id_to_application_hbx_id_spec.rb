# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Operations::Migrations::TaxHouseholdGroups::CopyApplicationIdToApplicationHbxId do
  subject { described_class.new }

  describe '#call' do
    let(:person1) { FactoryBot.create(:person, :with_consumer_role, :with_active_consumer_role) }
    let(:family1) { FactoryBot.create(:family, :with_primary_family_member, person: person1) }
    let(:tax_household_group1) { FactoryBot.create(:tax_household_group, family: family1, application_id: 'app1_123') }

    let(:person2) { FactoryBot.create(:person, :with_consumer_role, :with_active_consumer_role) }
    let(:family2) { FactoryBot.create(:family, :with_primary_family_member, person: person2) }
    let(:tax_household_group2) do
      FactoryBot.create(
        :tax_household_group,
        family: family2,
        application_id: 'app2_123',
        application_hbx_id: 'app2_hbx_id_123'
      )
    end

    let(:csv_file_name) { "#{Rails.root}/copy_application_id_to_application_hbx_id_report.csv" }

    after :all do
      csv_path = "#{Rails.root}/copy_application_id_to_application_hbx_id_report.csv"
      File.delete(csv_path) if File.exist?(csv_path)
    end

    context 'with a valid case' do
      before do
        tax_household_group1
      end

      it 'returns a success result' do
        expect(subject.call.success).to eq(
          "Successfully populated application_hbx_id for all the tax household groups. Please check the report: #{csv_file_name} for more details."
        )
      end

      it 'copies application_id to application_hbx_id' do
        subject.call
        expect(tax_household_group1.reload.application_hbx_id).to eq(tax_household_group1.application_id)
      end
    end

    context 'with an invalid case' do
      before do
        tax_household_group2
      end

      it 'returns a success result' do
        expect(subject.call.success).to eq(
          "Successfully populated application_hbx_id for all the tax household groups. Please check the report: #{csv_file_name} for more details."
        )
      end

      it 'does not copy application_id to application_hbx_id' do
        subject.call
        expect(tax_household_group2.reload.application_hbx_id).to eq('app2_hbx_id_123')
      end
    end

    context 'with both valid and invalid cases' do
      before :each do
        tax_household_group1
        tax_household_group2
      end

      it 'returns a success result' do
        expect(subject.call.success).to eq(
          "Successfully populated application_hbx_id for all the tax household groups. Please check the report: #{csv_file_name} for more details."
        )
      end

      it 'copies application_id to application_hbx_id for valid cases' do
        subject.call
        expect(tax_household_group1.reload.application_hbx_id).to eq(tax_household_group1.application_id)
        expect(tax_household_group2.reload.application_hbx_id).to eq('app2_hbx_id_123')
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Operations::Migrations::People::MigrateAiAnToAttestedStatus, dbclean: :after_each do

  context 'given a person with American Indian Status in outstanding state' do
    let!(:product) {FactoryBot.create(:benefit_markets_products_health_products_health_product, :ivl_product)}
    let!(:hbx_profile) {FactoryBot.create(:hbx_profile, :open_enrollment_coverage_period)}
    let!(:person) do
      FactoryBot.create(:person,
                        :with_consumer_role,
                        :with_active_consumer_role,
                        hbx_id: 'ff4489850cf44b30abd9523e3c515587',
                        last_name: 'Test',
                        first_name: 'Domtest34',
                        ssn: '243108282',
                        dob: Date.new(1984, 3, 8))
    end
    let!(:person2) do
      FactoryBot.create(:person,
                        :with_consumer_role,
                        :with_active_consumer_role,
                        hbx_id: 'ff4489850cf44b30abd9523e3c515589',
                        last_name: 'Test',
                        first_name: 'Domtest35',
                        ssn: '243108285',
                        dob: Date.new(1980, 6, 10))
    end

    before do
      person.verification_types.create!(type_name: 'American Indian Status', validation_status: 'unverified')
      person2.verification_types.create!(type_name: 'American Indian Status', validation_status: 'verified')
    end

    let(:filename) { "migrate_ai_an_to_attested_status_report_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.csv" }

    context 'when mode is :migrate_data' do
      let(:add_determination) { Operations::Migrations::People::MigrateAiAnToAttestedStatus.new.call }

      it 'should default magi_medicaid_monthly_income_limit to 0' do
        subject.call(mode: :migrate_data)

        person.reload
        american_indian_status = person.american_indian_status
        expect(american_indian_status.validation_status).to eq 'attested'
        expect(american_indian_status.update_reason).to eq 'Self Attest American Indian Status'
        expect(american_indian_status.type_history_elements.last.update_reason).to eq 'Policy change to accept self-attestation of American Indian status'
      end
    end

    context 'when mode is :report' do
      it 'should export tax household information with income values' do
        subject.call(mode: :report)

        csv_data = CSV.read("#{Rails.root}/#{filename}", :headers => true)
        expect(csv_data.size).to eq 1

        data_row = csv_data.first

        expect(data_row["Person hbx_id"]).to eq person.hbx_id
        expect(data_row["VerificationType name"]).to eq person.american_indian_status.type_name
        expect(data_row["VerificationType validation_status"]).to eq person.american_indian_status.validation_status
      end
    end
  end
end
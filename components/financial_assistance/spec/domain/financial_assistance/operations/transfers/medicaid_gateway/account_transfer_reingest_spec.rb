# frozen_string_literal: true

require 'rails_helper'
require 'aca_entities/serializers/xml/medicaid/atp'
require 'aca_entities/atp/transformers/cv/family'

RSpec.describe ::FinancialAssistance::Operations::Transfers::MedicaidGateway::AccountTransferReingest, dbclean: :after_each do
  include Dry::Monads[:do, :result]

  let(:xml_file_path) { ::FinancialAssistance::Engine.root.join('spec', 'shared_examples', 'medicaid_gateway', 'Simple_Test_Case_E_New.xml') }
  let(:xml) do
    Rails.cache.fetch("test_xml_string") do
      File.read(xml_file_path)
    end
  end

  let(:serializer) { ::AcaEntities::Serializers::Xml::Medicaid::Atp::AccountTransferRequest }
  let(:transformer) { ::AcaEntities::Atp::Transformers::Cv::Family }
  let(:atp_service) { ::FinancialAssistance::Operations::Transfers::MedicaidGateway::AccountTransferIn }

  let(:transformed_payload) do
    record = serializer.parse(xml)
    transformer.transform(record.to_hash(identifier: true))
  end

  context 'success' do
    before do
      atp_service.new.call(transformed_payload)
    end

    context 'Given there is an existing transferred application' do
      context 'when reingesting the same application payload' do

        it 'should update applicant data' do
          application = FinancialAssistance::Application.last
          expect(application.transferred_at).to be_present

          FinancialAssistance::Application.collection.update_one(
            { _id: application.id },
            { "$set" => { "applicants.$[].transfer_referral_reason" => nil } }
          )

          application.reload
          referral_reasons = application.applicants.pluck(:transfer_referral_reason).compact
          expect(referral_reasons).to be_empty

          record = serializer.parse(xml)
          payload = transformer.transform(record.to_hash(identifier: true))
          result = subject.call(payload)
          expect(result).to be_success
          expect(result.success).to eq application

          application.reload
          referral_reasons = application.applicants.pluck(:transfer_referral_reason).compact
          expect(referral_reasons).to be_present
        end
      end
    end
  end

  context 'Given there is no existing transferred application' do
    let(:apps) { []}

    before do
      atp_service.new.call(transformed_payload)
    end

    it 'should return a failure' do
      allow(FinancialAssistance::Application).to receive(:where).and_return(apps)

      record = serializer.parse(xml)
      payload = transformer.transform(record.to_hash(identifier: true))
      result = subject.call(payload)

      expect(result).to be_failure
      expect(result.failure).to eq "Application with transfer id #{payload['family']['magi_medicaid_applications'].first['transfer_id']} not found"
    end
  end

  context 'Given there are multiple matching transferred applications same transfer id' do
    let(:apps) { [double, double]}

    before do
      atp_service.new.call(transformed_payload)
    end

    it 'should return a failure' do
      allow(FinancialAssistance::Application).to receive(:where).and_return(apps)

      record = serializer.parse(xml)
      payload = transformer.transform(record.to_hash(identifier: true))
      result = subject.call(payload)

      expect(result).to be_failure
      expect(result.failure).to eq "Multiple applications found with transfer id #{payload['family']['magi_medicaid_applications'].first['transfer_id']}"
    end
  end
end

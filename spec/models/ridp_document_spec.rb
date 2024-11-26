require 'rails_helper'

RSpec.describe RidpDocument, :type => :model do
  let(:person) {FactoryBot.create(:person, :with_consumer_role)}
  let(:person2) {FactoryBot.create(:person, :with_consumer_role)}


  describe "creates person with ridp_docs" do
    it "creates scope for uploaded docs" do
      expect(person.consumer_role.ridp_documents).to exist
    end

    it "returns number of uploaded documents" do
      person2.consumer_role.ridp_documents.first.identifier = "url"
      expect(person2.consumer_role.ridp_documents.uploaded.count).to eq(1)
    end
  end

  context "verification reasons" do
    if EnrollRegistry[:enroll_app].setting(:site_key).item == :me
      it "should have crm document system as verification reason" do
        expect(VlpDocument::VERIFICATION_REASONS).to include("Self-Attestation")
        expect(RidpDocument::VERIFICATION_REASONS).to include("CRM Document Management System")
        expect(EnrollRegistry[:verification_reasons].item).to include("CRM Document Management System")
      end
    end
    if EnrollRegistry[:enroll_app].setting(:site_key).item == :dc
      it "should have salesforce as verification reason" do
        expect(VlpDocument::VERIFICATION_REASONS).to include("Self-Attestation")
        expect(RidpDocument::VERIFICATION_REASONS).to include("Salesforce")
        expect(EnrollRegistry[:verification_reasons].item).to include("Salesforce")
      end
    end
  end

  context "rejection reasons" do
    context "out of income threshold reason enabled" do
      before do
        # Because the constants are frozen, we need to remove the model and reload the file
        # after setting the FF in order to test what happens when the feature is enabled
        Object.send(:remove_const, :RidpDocument) if Module.const_defined?(:RidpDocument)
        allow(EnrollRegistry).to receive(:feature_enabled?).and_return(true)
        allow(EnrollRegistry).to receive(:feature_enabled?).with(:out_of_income_threshold_reject_reason).and_return(true)
        load 'app/models/ridp_document.rb'
      end

      it "should include Out of Income Threshold as a rejection reason" do
        expect(RidpDocument::RETURNING_FOR_DEF_REASONS).to include("Out of Income Threshold")
      end
    end

    context "out of income threshold reason disabled" do
      before do
        Object.send(:remove_const, :RidpDocument) if Module.const_defined?(:RidpDocument)
        allow(EnrollRegistry).to receive(:feature_enabled?).and_return(false)
        allow(EnrollRegistry).to receive(:feature_enabled?).with(:out_of_income_threshold_reject_reason).and_return(false)
        load 'app/models/ridp_document.rb'
      end

      it "should not include Out of Income Threshold as a rejection reason" do
        expect(RidpDocument::RETURNING_FOR_DEF_REASONS).not_to include("Out of Income Threshold")
      end
    end
  end
end

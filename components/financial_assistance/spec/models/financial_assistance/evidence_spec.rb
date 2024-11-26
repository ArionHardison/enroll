# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::FinancialAssistance::Evidence, type: :model, dbclean: :after_each do
  context "rejection reasons" do
    context "out of income threshold reason enabled" do
      before do
        # Because the constants are frozen, we need to remove the model and reload the file
        # after setting the FF in order to test what happens when the feature is enabled
        Object.const_get(:FinancialAssistance).send(:remove_const, :Evidence) if defined?(::FinancialAssistance::Evidence)
        allow(EnrollRegistry).to receive(:feature_enabled?).and_return(true)
        allow(EnrollRegistry).to receive(:feature_enabled?).with(:out_of_income_threshold_reject_reason).and_return(true)
        load 'components/financial_assistance/app/models/financial_assistance/evidence.rb'
      end

      it "should include Out of Income Threshold as a rejection reason" do
        expect(::FinancialAssistance::Evidence::REJECT_REASONS).to include("Out of Income Threshold")
      end
    end

    context "out of income threshold reason disabled" do
      before do
        Object.const_get(:FinancialAssistance).send(:remove_const, :Evidence) if defined?(::FinancialAssistance::Evidence)
        allow(EnrollRegistry).to receive(:feature_enabled?).and_return(false)
        allow(EnrollRegistry).to receive(:feature_enabled?).with(:out_of_income_threshold_reject_reason).and_return(false)
        load 'components/financial_assistance/app/models/financial_assistance/evidence.rb'
      end

      it "should not include Out of Income Threshold as a rejection reason" do
        expect(::FinancialAssistance::Evidence::REJECT_REASONS).not_to include("Out of Income Threshold")
      end
    end
  end
end

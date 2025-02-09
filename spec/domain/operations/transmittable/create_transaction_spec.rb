# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Operations::Transmittable::CreateTransaction, dbclean: :after_each do
  subject { described_class.new }
  let(:key) { :ssa_verification_request}
  let(:title) { 'SSA Verification Request'}
  let(:description) { 'Request for SSA verification to CMS'}
  let(:transmission) { FactoryBot.create(:transmittable_transmission) }
  let(:application) { FinancialAssistance::Application.create }
  let(:required_params) do
    {
      key: key,
      started_at: DateTime.now,
      transmission: transmission,
      subject: application,
      event: 'initial',
      state_key: :initial
    }
  end

  let(:optional_params) do
    {
      title: title,
      description: description
    }
  end

  let(:all_params) { required_params.merge(optional_params) }

  context 'sending invalid params' do

    context 'key' do
      it 'should return a failure with missing key' do
        result = subject.call(required_params.except(:key))
        expect(result.failure).to eq('Transaction cannot be created without key symbol')
      end

      it 'should return a failure when key is not a symbol' do
        required_params[:key] = "Key"
        result = subject.call(required_params)
        expect(result.failure).to eq('Transaction cannot be created without key symbol')
      end
    end

    context 'started_at' do
      it 'should return a failure with missing started_at' do
        result = subject.call(required_params.except(:started_at))
        expect(result.failure).to eq('Transaction cannot be created without started_at datetime')
      end

      it 'should return a failure when started_at is not a Datetime' do
        required_params[:started_at] = Date.today
        result = subject.call(required_params)
        expect(result.failure).to eq('Transaction cannot be created without started_at datetime')
      end
    end

    context 'transmission' do
      it 'should return a failure with missing transmission' do
        result = subject.call(required_params.except(:transmission))
        expect(result.failure).to eq('Transaction cannot be created without a transmission')
      end

      it 'should return a failure when transmission is not a transmission object' do
        required_params[:transmission] = Date.today
        result = subject.call(required_params)
        expect(result.failure).to eq('Transaction cannot be created without a transmission')
      end
    end

    context 'subject' do
      it 'should return a failure with missing subject' do
        result = subject.call(required_params.except(:subject))
        expect(result.failure).to eq('Transaction cannot be created without a subject')
      end
    end

    context 'event' do
      it 'should return a failure with missing event' do
        result = subject.call(required_params.except(:event))
        expect(result.failure).to eq('Transaction cannot be created without event string')
      end

      it 'should return a failure when event is not a string' do
        required_params[:event] = Date.today
        result = subject.call(required_params)
        expect(result.failure).to eq('Transaction cannot be created without event string')
      end
    end

    context 'state_key' do
      it 'should return a failure with missing state_key' do
        result = subject.call(required_params.except(:state_key))
        expect(result.failure).to eq('Transaction cannot be created without state_key symbol')
      end

      it 'should return a failure with missing state_key' do
        required_params[:state_key] = Date.today
        result = subject.call(required_params)
        expect(result.failure).to eq('Transaction cannot be created without state_key symbol')
      end
    end
  end

  context 'sending valid params' do
    before do
      @result = subject.call(all_params)
    end

    it "Should not have any errors" do
      expect(@result.success?).to be_truthy
    end

    it 'should generate a transaction' do
      expect(@result.value!.class).to eq Transmittable::Transaction
    end

    it 'should create a transactions_transmissions' do
      expect(@result.value!.transactions_transmissions.first.transmission_id).to eq transmission.id
    end
  end
end

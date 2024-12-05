# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Operations::DeleteHbxProfileMessages do
  include Dry::Monads[:result]

  before :all do
    DatabaseCleaner.clean
  end

  after :all do
    DatabaseCleaner.clean
  end

  describe '#call' do
    let(:hbx_profile) { FactoryBot.create(:hbx_profile) }

    before :each do
      allow(HbxProfile).to receive(:find_by_state_abbreviation).and_return hbx_profile
    end

    context 'success' do
      let(:message) { Message.new(subject: 'test subject', body: 'test message') }

      before :each do
        hbx_profile.inbox.messages << message
        hbx_profile.save
      end

      it 'returns a success monad' do
        result = subject.call
        expect(result.success).to be_truthy
      end

      it 'creates a CSV' do
        file_name = subject.call.success
        csv_file_name = file_name.split(': ').last
        expect(
          File.exist?(csv_file_name)
        ).to be_truthy
      end

      it 'deletes hbx profile messages' do
        subject.call
        hbx_profile.reload
        expect(hbx_profile.inbox.messages.count).to eq(0)
      end
    end

    context 'failure' do
      context 'when there are no inblox messages' do

        it 'returns a failure monad' do
          expect(subject.call.failure).to eq('No messages found')
        end
      end
    end
  end
end

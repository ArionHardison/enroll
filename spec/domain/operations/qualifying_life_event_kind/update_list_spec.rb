# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Operations::QualifyingLifeEventKind::UpdateList, type: :model, dbclean: :after_each do

  before :all do
    DatabaseCleaner.clean
  end

  let!(:qlek1) { FactoryBot.create(:qualifying_life_event_kind, ordinal_position: 1, is_common: true, is_active: true) }
  let!(:qlek2) { FactoryBot.create(:qualifying_life_event_kind, ordinal_position: 2, is_active: true, is_common: true) }
  let!(:future_qle) { FactoryBot.create(:qualifying_life_event_kind, ordinal_position: 10, is_common: false, is_active: true, start_on: TimeKeeper.date_of_record.next_month) }
  market_kind = 'shop'

  let!(:sort_params) do
    { 'market_kind' => market_kind,
      'sort_data' => [
        {'id' => qlek2.id.to_s, 'position' => 1},
        {'id' => qlek1.id.to_s, 'position' => 3},
        {'id' => future_qle.id.to_s, 'position' => 2}
      ]}
  end

  let!(:commonality_threshold_params) do
    { 'market_kind' => 'shop', 'commonality_threshold' => '1' }
  end

  context 'update ordinal_position' do
    before :each do
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:qle_commonality_threshold).and_return(true)
      @result = subject.call(params: sort_params)
      qlek1.reload
      qlek2.reload
      future_qle.reload
    end

    it 'should return success' do
      expect(@result).to be_a(Dry::Monads::Result::Success)
    end

    it 'should update ordinal_positions of qlek objects' do
      expect(qlek1.ordinal_position).to eq(3)
      expect(qlek2.ordinal_position).to eq(1)
      expect(future_qle.ordinal_position).to eq(2)
    end

    it 'should update is_common of qlek objects' do
      expect(qlek1.is_common).to eq(false)
      expect(qlek2.is_common).to eq(true)
      expect(future_qle.is_common).to eq(true)
    end
  end

  context 'update commonality_threshold' do
    before :each do
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:qle_commonality_threshold).and_return(true)
      @result = subject.call(params: commonality_threshold_params)
      qlek1.reload
      qlek2.reload
      future_qle.reload
    end

    it 'should return success' do
      expect(@result).to be_a(Dry::Monads::Result::Success)
    end

    it 'should update is_commons of qlek objects' do
      expect(qlek1.is_common).to eq(true)
      expect(qlek2.is_common).to eq(false)
      expect(future_qle.is_common).to eq(false)

      qleks = QualifyingLifeEventKind.by_market_kind(market_kind).active_by_state
      expect(qleks.common.length).to eq(1)
      expect(qleks.rare.length).to eq(2)
    end

    it 'should preserve ordinal_positions of qlek objects' do
      expect(qlek1.ordinal_position).to eq(1)
      expect(qlek2.ordinal_position).to eq(2)
      expect(future_qle.ordinal_position).to eq(10)
    end
  end
end

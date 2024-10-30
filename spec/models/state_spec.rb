# frozen_string_literal: true

RSpec.describe State, type: :model, dbclean: :after_each do

  it "has a state array with the base 56 states" do
    expect(State::STATE_LIST).not_to be_empty
    expect(State::STATE_LIST.first).to be_an_instance_of(Array)
    expect(State::STATE_LIST.length).to eq(56)
  end

  it "they state array contains names and IDs" do
    expect(State::STATE_LIST.first.length).to eq(2)
    expect(State::STATE_LIST.first.first).to eq("Alabama")
    expect(State::STATE_LIST.first.last).to eq("AL")
  end

  context "when the TBD feature flag is set to false" do
    before do
      allow(EnrollRegistry).to receive(:feature_enabled?).and_return(true)
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:increase_state_client_prominence).and_return(false)
    end

    it "has a client specific value that is nil" do
      expect(State::CLIENT_STATE).to be_nil
    end

    it "should have a STATE_IDS array with the base 56 states limited to IDs and sorted alphabetically" do
      expect(State::STATE_IDS).not_to be_empty
      expect(State::STATE_IDS.first).to be_an_instance_of(String)
      expect(State::STATE_IDS.length).to eq(56)
      expect(State::STATE_IDS.first).to eq("AK")
    end

    it "should have a NAMES_AND_IDS array with the base 56 states with both names and IDs" do
      expect(State::NAMES_AND_IDS).not_to be_empty
      expect(State::NAMES_AND_IDS).to eq(State::STATE_LIST)
    end
  end

  context "when the TBD feature flag is set to true " do
    before do
      # Because the constants are frozen, we need to remove the model and reload the file
      # after setting the FF in order to test what happens when the feature is enabled
      Object.send(:remove_const, :State) if Module.const_defined?(:State)
      allow(EnrollRegistry).to receive(:feature_enabled?).and_return(true)
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:increase_state_client_prominence).and_return(true)
      load 'app/models/state.rb'
    end
    it "client array should not be nil if feature flag is enabled" do
      expect(State::CLIENT_STATE).not_to be_nil
      expect(State::CLIENT_STATE).to be_an_instance_of(Array)
    end
    it "should have a STATE_IDS array that includes an additional instance of the client, limited to IDs" do
      expect(State::STATE_IDS).not_to be_empty
      expect(State::STATE_IDS.first).to be_an_instance_of(String)
      expect(State::STATE_IDS.length).to eq(57)
      expect(State::STATE_IDS.first).to eq(State::CLIENT_STATE.last)
      expect(State::STATE_IDS.last).to eq("WY")
    end
    it "should have a NAMES_AND_IDS array that includes an additional instance of the client, with both names and IDs" do
      expect(State::NAMES_AND_IDS).not_to be_nil
      expect(State::NAMES_AND_IDS.first).to be_an_instance_of(Array)
      expect(State::NAMES_AND_IDS.length).to eq(57)
      expect(State::NAMES_AND_IDS.first.first).to eq(State::CLIENT_STATE.first)
      expect(State::NAMES_AND_IDS.last.first).to eq("Wyoming")
    end
  end

end

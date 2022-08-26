# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Operations::BenchmarkProducts::IdentifyTypeOfHousehold do
  describe '#call' do
    let(:params) do
      {
        family_id: family_id,
        effective_date: start_of_year,
        primary_rating_address_id: BSON::ObjectId.new,
        rating_area_id: BSON::ObjectId.new,
        exchange_provided_code: 'R-ME001',
        service_area_ids: [BSON::ObjectId.new],
        group_benchmark_ehb_premium: 200.90,
        households: [
          {
            type_of_household: 'adult_only',
            household_benchmark_ehb_premium: 200.90,
            health_product_hios_id: '123',
            health_product_id: BSON::ObjectId.new,
            health_ehb: 0.99,
            total_health_benchmark_ehb_premium: 200.90,
            health_product_covers_pediatric_dental_costs: true,
            members: [
              {
                family_member_id: family_member1.id,
                relationship_kind: 'self',
                date_of_birth: family_member1.dob,
                age_on_effective_date: family_member1_age
              },
              {
                family_member_id: family_member2.id,
                relationship_kind: 'spouse',
                date_of_birth: family_member2.dob,
                age_on_effective_date: family_member2_age
              }
            ]
          }
        ]
      }
    end
    let(:start_of_year) { TimeKeeper.date_of_record.beginning_of_year }
    let(:benchmark_product_model) { ::Operations::BenchmarkProducts::Initialize.new.call(params) }

    context 'valid input' do
      let(:person1) do
        per = FactoryBot.create(:person, :with_consumer_role, :with_active_consumer_role, dob: start_of_year - family_member1_age.years)
        per.rating_address.update_attributes!(county: 'York', zip: '04001', state: 'ME')
        per
      end
      let(:person2) do
        per = FactoryBot.create(:person, :with_consumer_role, :with_active_consumer_role, dob: start_of_year - family_member2_age.years)
        person1.ensure_relationship_with(per, 'spouse')
        per
      end
      let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person1) }
      let(:family_member1) { family.primary_applicant }
      let(:family_member2) { FactoryBot.create(:family_member, family: family, person: person2) }
      let(:family_id) { family.id }

      context 'adult_only' do
        let(:family_member1_age) { 35 }
        let(:family_member2_age) { 35 }

        it 'should return entity object' do
          expect(
            subject.call(params).success[1].households.first.type_of_household
          ).to eq('adult_only')
        end
      end

      context 'child_only' do
        let(:family_member1_age) { 15 }
        let(:family_member2_age) { 15 }

        it 'should return entity object' do
          expect(
            subject.call(params).success[1].households.first.type_of_household
          ).to eq('child_only')
        end
      end

      context 'adult_and_child' do
        let(:family_member1_age) { 35 }
        let(:family_member2_age) { 15 }

        it 'should return entity object' do
          expect(
            subject.call(params).success[1].households.first.type_of_household
          ).to eq('adult_and_child')
        end
      end
    end

    context 'invalid params' do
      let(:family_member1) { double(id: 'family_member_id', dob: start_of_year) }
      let(:family_member2) { double(id: 'family_member_id', dob: start_of_year) }
      let(:family_member1_age) { 35 }
      let(:family_member2_age) { 35 }

      context 'no family' do
        let(:family_id) { 'family_id' }

        it 'should return errors' do
          result = subject.call(params)
          expect(result.failure).to eq("Unable to find Family with family_id: #{family_id}")
        end
      end

      context 'no family_member' do
        let(:family_id) { FactoryBot.create(:family, :with_primary_family_member).id }

        it 'should return errors' do
          result = subject.call(params)
          expect(result.failure).to eq("Unable to find FamilyMember for family_id: #{family_id}, with family_member_id: #{family_member1.id}")
        end
      end
    end
  end
end

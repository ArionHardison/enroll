# frozen_string_literal: true

require 'rails_helper'

describe Queries::BrokerAgencyDatatableQuery, dbclean: :after_each do
  subject { Queries::BrokerAgencyDatatableQuery.new({}) }

  context "default query" do
    it "builds scope with selector for brokers" do
      expect(subject.build_scope.selector).to eq({"profiles._type" => /.*BrokerAgencyProfile$/})
    end

    context "is paginated" do
      let!(:skip) { 64 }
      let!(:limit) { 4 }
      before { subject.skip(skip).limit(limit) }

      it "builds query with pagination" do
        expect(subject.build_query.options).to eq(skip: skip, limit: limit)
      end
    end
  end

  context "performs search" do
    let!(:search_query) { "test_search_query" }
    let!(:profile) do
      profile = FactoryBot.create(:broker_agency_profile)
      FactoryBot.create(
        :person,
        first_name: search_query, # test search using first_name of the person with broker role in broker_agency_profile
        broker_agency_staff_roles: [FactoryBot.create(:broker_agency_staff_role, broker_agency_profile: profile)]
      )
      profile
    end

    before { subject.instance_variable_set(:@search_string, search_query) }

    it "builds scope with selector for search query" do
      expect(subject.build_scope.selector).to eq(
        {
          "profiles._type" => /.*BrokerAgencyProfile$/,
          "$or" => [
            {"legal_name" => /#{search_query}/i},
            {"fein" => /#{search_query}/i},
            {"hbx_id" => /#{search_query}/i},
            {"profiles._id" => {"$in" => [profile.id]}}
          ]
        }
      )
    end
  end

  context "performs order" do
    shared_examples "ordering by legal name" do |order|
      def create_organization(legal_name)
        FactoryBot.create(
          :benefit_sponsors_organizations_general_organization,
          :with_broker_agency_profile,
          legal_name: legal_name,
          site: FactoryBot.create(
            :benefit_sponsors_site,
            :with_benefit_market,
            :as_hbx_profile,
            site_key: ::EnrollRegistry[:enroll_app].settings(:site_key).item
          )
        )
      end

      let!(:organization_1) { create_organization("A") }
      let!(:organization_2) { create_organization("B") }
      let!(:organization_3) { create_organization("C") }

      before { subject.instance_variable_set(:@order_by, {"legal_name" => order}) }

      it "builds query with #{order == :asc ? 'ascending' : 'descending'} order by legal name" do
        expected_order = [organization_1, organization_2, organization_3]
        expected_order.reverse! if order == :desc
        expect(subject.build_query.options[:sort]).to eq({"legal_name" => order == :asc ? 1 : -1})
        expect(subject.build_query.to_a).to eq(expected_order)
      end
    end

    it_behaves_like "ordering by legal name", :asc
    it_behaves_like "ordering by legal name", :desc
  end
end

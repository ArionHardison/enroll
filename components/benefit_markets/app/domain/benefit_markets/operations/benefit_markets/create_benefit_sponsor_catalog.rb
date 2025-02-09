# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitMarkets
  module Operations
    module BenefitMarkets
      # Creates benefit sponsor catalog entity
      class CreateBenefitSponsorCatalog
        include Dry::Monads[:do, :result]

        attr_reader :enrollment_eligibility

        # Executes the creation process for a Benefit Sponsor Catalog.
        # This method takes a hash of parameters, performs a series of operations
        # to find the benefit market catalog, get enrollment policies, build product packages, and create the benefit sponsor catalog.
        #
        # @param params [Hash] A hash containing :enrollment_eligibility.
        #   - :enrollment_eligibility [EnrollmentEligibility] The enrollment eligibility criteria.
        #
        # @return [Dry::Monads::Result] A Success or Failure monad.
        #   - Success: Contains the created Benefit Sponsor Catalog.
        #   - Failure: Contains an error message.
        def call(params)
          benefit_market_catalog = yield find_benefit_market_catalog(params[:enrollment_eligibility])
          sponsor_catalog_params = yield get_enrollment_policies(benefit_market_catalog)
          product_packages       = yield build_product_packages(benefit_market_catalog, sponsor_catalog_params[:effective_period])
          sponsor_catalog        = yield create(sponsor_catalog_params, product_packages)

          Success(sponsor_catalog)
        end

        private

        def get_enrollment_policies(benefit_market_catalog)
          benefit_market_catalog = benefit_market_catalog.value!
          effective_date = enrollment_eligibility.effective_date
          policies = {
            effective_date: effective_date,
            effective_period: benefit_market_catalog.effective_period_on(effective_date),
            open_enrollment_period: benefit_market_catalog.open_enrollment_period_on(effective_date),
            probation_period_kinds: benefit_market_catalog.probation_period_kinds,
            service_area_ids: enrollment_eligibility.service_areas.pluck(:_id)
          }

          Success(policies)
        end

        def eligible_product_packages(catalog)
          if enrollment_eligibility.metal_level_products_restricted?
            catalog.product_packages.reject{|package| package.product_kind == :health && package.package_kind != :metal_level}
          else
            catalog.product_packages
          end
        end

        def build_product_packages(benefit_market_catalog, application_period)
          benefit_market_catalog = benefit_market_catalog.value!
          product_packages = eligible_product_packages(benefit_market_catalog).collect do |product_package|
            product_package_entity_for(product_package, application_period)
          end

          if product_packages.none?(&:failure?)
            Success(product_packages.map(&:value!))
          else
            Failure(product_packages.reduce([]){|list, package| list << package.failure if package.failure? })
          end
        end

        def product_package_entity_for(product_package, application_period)
          package_kind               = product_package[:package_kind]
          product_package_params     = product_package.serializable_hash.deep_symbolize_keys.except(:products)
          contribution_models_params = product_package_params.delete(:contribution_models) || []
          contribution_model_params  = product_package_params.delete(:contribution_model)
          pricing_units_params       = product_package_params[:pricing_model].delete(:pricing_units)
          product_package_params[:application_period]            = application_period
          product_package_params[:products]                      = filter_products_by_service_areas(product_package).value!
          # Skipping because we are not creating contribution models for dental as they don't have relaxed rules.
          product_package_params[:contribution_models]           = contribution_models_for(contribution_models_params) if product_package[:product_kind] == :health
          product_package_params[:contribution_model]            = build_contribution_model_entity(contribution_model_params)
          product_package_params[:pricing_model][:pricing_units] = build_pricing_units_entities(pricing_units_params, package_kind)

          apply_product_eligibility_grants(product_package_params)

          ::BenefitMarkets::Operations::ProductPackages::Create.new.call(product_package_params: product_package_params, enrollment_eligibility: enrollment_eligibility)
        end

        def apply_product_eligibility_grants(product_package_params)
          return unless enrollment_eligibility.metal_level_products_restricted?
          product_package_params[:products].reject!{|product| product.kind == :health && product.metal_level_kind == :bronze}
        end

        def create(sponsor_catalog_params, product_packages)
          benefit_sponsor_catalog = ::BenefitMarkets::Operations::BenefitSponsorCatalogs::Create.new.call(sponsor_catalog_params: sponsor_catalog_params.merge(product_packages: product_packages))

          if benefit_sponsor_catalog.success?
            Success(benefit_sponsor_catalog.value!)
          else
            Failure(benefit_sponsor_catalog.failure)
          end
        end

        def find_benefit_market_catalog(enrollment_eligibility)
          @enrollment_eligibility = enrollment_eligibility
          market_catalog = ::BenefitMarkets::Operations::BenefitMarketCatalogs::FindModel.new.call(effective_date: enrollment_eligibility.effective_date, market_kind: enrollment_eligibility.market_kind)

          Success(market_catalog)
        end

        def filter_products_by_service_areas(product_package)
          ::BenefitMarkets::Operations::Products::Find.new.call(effective_date: enrollment_eligibility.effective_date, service_areas: enrollment_eligibility.service_areas, product_package: product_package)
        end

        def contribution_unit_models_for(contribution_model_params)
          sponsor_contribution_kind = contribution_model_params[:sponsor_contribution_kind]
          contribution_model_params[:contribution_units].collect do |contribution_unit_params|
            result = ::BenefitMarkets::Operations::ContributionUnits::Create.new.call(contribution_unit_params: contribution_unit_params, sponsor_contribution_kind: sponsor_contribution_kind)
            if result.success?
              result.value!
            else
              Failure(result)
            end
          end
        end

        def build_pricing_units_entities(pricing_units_params, package_kind)
          pricing_units_params.collect do |pricing_unit_params|
            ::BenefitMarkets::Operations::PricingUnits::Create.new.call(pricing_unit_params: pricing_unit_params, package_kind: package_kind).value!
          end
        end

        def build_contribution_model_entity(params)
          params[:contribution_units] = contribution_unit_models_for(params)
          contribution_model_entity = ::BenefitMarkets::Operations::ContributionModels::Create.new.call(contribution_params: params).value!
        end


        def contribution_models_for(contribution_models_params)
          contribution_models_params.collect do |contribution_model_params|
            build_contribution_model_entity(contribution_model_params)
          end
        end
      end
    end
  end
end

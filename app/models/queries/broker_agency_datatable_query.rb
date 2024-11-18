# frozen_string_literal: true

module Queries
  # Wrapper around Mongoid::Criteria to provide datatable search, pagination, and ordering
  class BrokerAgencyDatatableQuery
    include Sorter

    attr_reader :search_string, :custom_attributes

    def datatable_search(string)
      @search_string = string
      self
    end

    def initialize(attributes)
      @custom_attributes = attributes
    end

    def build_scope
      scope = klass.broker_agency_profiles
      scope.order_by(@order_by) if @order_by
      return scope unless @search_string

      scope.datatable_search(@search_string)
    end

    def build_query
      limited_scope = build_scope
      limited_scope = sort_query(limited_scope, @order_by) if @order_by
      paginate(limited_scope)
    end

    def each(&block)
      return to_enum(:each) unless block

      build_query.each(&block)
    end

    def each_with_index(&block)
      return to_enum(:each_with_index) unless block

      build_query.each_with_index(&block)
    end

    def skip(num)
      @skip = num
      self
    end

    def limit(num)
      @limit = num
      self
    end

    def order_by(var)
      @order_by = var
      self
    end

    def klass
      BenefitSponsors::Organizations::Organization
    end

    def size
      build_scope.count
    end
  end
end

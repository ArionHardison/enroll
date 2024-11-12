module Queries
  class IdentityVerificationDatatableQuery
    include Sorter

    attr_reader :search_string, :custom_attributes

    AGGREGATABLE_COLUMNS = {"name" => :sort_by_full_name_pipeline}.freeze

    def datatable_search(string)
      @search_string = string
      self
    end

    def initialize(attributes)
      @custom_attributes = attributes
    end

    def person_search search_string
      return Family if search_string.blank?
    end

    def build_scope()
      family = EnrollRegistry.feature_enabled?(:show_people_with_no_evidence) ? Person.for_admin_approval : Person.for_admin_approval_with_documents
      person = Person
      #add other scopes here
      return family if @search_string.blank? || @search_string.length < 2
      person_id = Person.search(@search_string).pluck(:_id)
      #Caution Mongo optimization on chained "$in" statements with same field
      #is to do a union, not an interactionl
      family.and('_id' => {"$in" => person_id})
    end

    def build_query
      limited_scope = build_scope
      limited_scope = sort_query(limited_scope, @order_by) if @order_by
      paginate(limited_scope)
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

    def each(&block)
      return to_enum(:each) unless block

      build_query.each(&block)
    end

    def each_with_index(&block)
      return to_enum(:each_with_index) unless block

      build_query.each_with_index(&block)
    end

    def klass
      Person
    end

    def size
      build_scope.count
    end

  end
end

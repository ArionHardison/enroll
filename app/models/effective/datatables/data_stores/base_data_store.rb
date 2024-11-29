# frozen_string_literal: true

module Effective
  module Datatables
    module DataStores
      # Base class for data stores that manage and provide expensive data for datatables.
      class BaseDataStore
        # The expiry time for the cache, set to 10 minutes.
        EXPIRY_TIME = 10.minutes
        COMPUTATION_TIME = 4.seconds

        # Sets up the cache by writing the `compute_cache`` to the cache with the specified expiry time.
        # NOTE: This method is called by the base `Datatable` instance in the gem in `view=` conditionally when
        #  a) the `Datable` subclass has a `DATA_STORE` constant defined, and
        #  b) the `Datable` subclass instance is initialized during a non-AJAX request, i.e., for page loads and not sort/filter/order requests.
        def self.setup
          Rails.cache.write(cache_key, compute_cache, expires_in: EXPIRY_TIME)
        end

        # Retrieves the data from the cache, or sets it if it doesn't exist, with the specified expiry time.
        def self.data
          Rails.cache.fetch(cache_key, expires_in: EXPIRY_TIME, race_condition_ttl: COMPUTATION_TIME) { compute_cache }
        end

        # Fetches the projected field from the cached data for a given document.
        #
        # @param document [Object] The document object.
        # @return [Object] The value of the field for the given document, or 0 if not found.
        def self.fetch_field(document)
          data&.fetch(document.id, cached_data_field_default_value)
        end

        # Generates a cache key based on the class name.
        #
        # @return [String] The cache key.
        def self.cache_key
          name.underscore.gsub('/', '_')
        end

        # Sets the hash to be cached by aggregating data from the model class.
        #
        # @return [Hash] The hash to be cached.
        def self.compute_cache
          pipeline = model_class.send(model_method)
          result = model_class.collection.aggregate(pipeline)
          field_name = derive_cached_data_field(pipeline)
          result.each_with_object({}) do |doc, hash|
            hash[doc["_id"]] = doc[field_name]
          end
        end

        # Derives the field name to be cached from the pipeline.
        #
        # @param pipeline [Array] The aggregation pipeline.
        # @return [String, nil] The field name to be cached, or nil if not found.
        def self.derive_cached_data_field(pipeline)
          return unless pipeline.any?
          pipeline.last["$project"].except("_id").keys.first
        end

        # Abstract method to be implemented by subclasses to define the default value for the projected field.
        #
        # @return [Object] The default value for the projected field.
        def self.cached_data_field_default_value
          nil
        end

        # Abstract method to be implemented by subclasses to define the model class.
        #
        # @raise [NotImplementedError] If the method is not implemented by the subclass.
        def self.model_class
          raise NotImplementedError, "Subclasses must define `model_class`."
        end

        # Abstract method to be implemented by subclasses to define the model method.
        #
        # @raise [NotImplementedError] If the method is not implemented by the subclass.
        def self.model_method
          raise NotImplementedError, "Subclasses must define `model_method`."
        end

        private_class_method :cache_key, :compute_cache, :derive_cached_data_field, :model_class, :model_method
      end
    end
  end
end

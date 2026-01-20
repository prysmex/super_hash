module SuperHash
  module Hasher
    # Adds support for ActiveSupport::HashWithIndifferentAccess
    #
    # NOTE: Currently, only string attributes are supported
    module IndifferentAccess

      # Class methods for IndifferentAccess
      module ClassMethods
        # @override
        #
        # Enforce attributes as strings
        def register_attribute(attribute_name, ...)
          unless attribute_name.is_a?(String)
            raise TypeError.new("attributes must be strings when IndifferentAccess, got: #{attribute_name.class.name}")
          end

          super
        end
      end

      def self.included(base)
        base.extend ClassMethods
        base.send(:attr_reader, :init_options) unless respond_to? :init_options
      end

      # prevent bug when an attribute has a default Proc and the attribute is a string but passed value
      # is a symbol
      #
      # @example
      #   attribute 'allOf', default: ->(data) { [].freeze } # passed data => {allOf: []}
      def initialize(init_value = {}, init_options = {}, single_time_options = nil)
        # save init_options so we can pass them on #dup
        @init_options = init_options

        # ensure all keys are strings
        unless init_value.is_a?(ActiveSupport::HashWithIndifferentAccess)
          init_value&.transform_keys! { |k| convert_key(k) }
        end

        init_options = init_options.merge(single_time_options) if single_time_options

        super(init_value, init_options)
      end

      # Ensure key is string since the beggining since SuperHash::Hasher methods are called
      # before ActiveSupport::HashWithIndifferentAccess logic happens.
      #
      # @override
      # @see []= (super runs after validation and other logic)
      def []=(key, value, **params)
        super(convert_key(key), convert_value(value), **params)
      end

      # @override @see https://github.com/rails/rails/blob/v8.0.4/activesupport/lib/active_support/hash_with_indifferent_access.rb#L256
      #
      # Override for 2 reasons:
      #   - Ensure passed instance is a hash by calling `to_hash`. Another option could be to deep dup passed
      #     values on initialization (existing app code may actually expect mutations to happen, would need to fix).
      #     (Needed with `force_default_init`?)
      #   - ActiveSupport::HashWithIndifferentAccess has its own implementation of dup, which ignores all
      #     instance variables. At least handle the simplest case where initialization options are passed
      #     again so any instance variables set during initialization are set in the same way on the dupped object.
      #     @see https://github.com/rails/rails/issues/43602
      #
      # NOTE: Also called by deep_dup @see https://github.com/rails/rails/blob/v8.0.4/activesupport/lib/active_support/core_ext/object/deep_dup.rb
      #
      def dup
        copy_defaults(self.class.new(to_hash, init_options, {force_default_init: true}))
      end
    end
  end
end
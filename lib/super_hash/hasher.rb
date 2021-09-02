require_relative 'version'

module Types
  def self.included(base)
    require 'dry-types'
    include Dry.Types()
  end
end

module SuperHash

  # The idea of the SuperHash is to have hashes with extended
  # functionality by adding the concept of *attributes*.
  # Attributes allow to have a powerful API for controlling
  # what data can be set and more control over how the data
  # is managed. Here is a list of all the features that the
  # SuperHash provides:
  #
  # - all the power of dry-types gem for each attribute!
  # - requiring some keys to be present with error raising
  # - setting a default value to a key
  # - setting transforms for specific keys
  # - accepting only whitelisted keys
  #   - This is the default behavior, if dynamic attributes are
  #     required set @allow_dynamic_attributes to true in class
  #
  # There are two basic class methods to define an attribute
  #
  #   - attribute, defines a required attribute
  #   - attribute?, defines an optional attribute
  #
  # Both attribute and attribute? support the following options in the options hash
  #
  # * type - DryType definition for value validation, see gem docs
  # * default - Default value that can also be a proc evaluated at the instance level
  # * transform - A proc that will be evaluated at the instance level
  #
  # @example required and type
  #
  #   attribute :key_name, type: Types::Hash.default({}.freeze)
  #   attribute :key_name, type: Types::String.optional
  #
  # @example required with instance level Proc
  #
  #   attribute :key_name, default: ->(instance) { instance[:other_attribute] }
  #
  # @example optional with instance level Proc
  #
  #   attribute? :key_name, transform: All_OF_PROC
  #
  module Hasher
    
    # ToDo only include if configured
    include Types

    ATTRIBUTE_CLASSES = [
      ::Symbol, ::String, ::Integer, ::Float
    ].freeze

    def self.included(base)
      base.alias_method :orig_writer, :[]= unless base.method_defined?(:orig_writer)
      base.alias_method :orig_update, :update unless base.method_defined?(:orig_update)

      base.extend ClassMethods
      base.include InstanceMethods

      base.instance_variable_set('@attributes', {})
      base.instance_variable_set('@after_set_callbacks', [])
      base.instance_variable_set('@allow_dynamic_attributes', false)
      base.instance_variable_set('@ignore_nil_default_values', true)
    end

    module ClassMethods
      attr_reader :attributes
      attr_reader :after_set_callbacks
      attr_reader :allow_dynamic_attributes
      attr_reader :ignore_nil_default_values

      # when a class in inherited from this one, add it to subclasses and
      # set instance variables
      def inherited(klass)
        super
        (@subclasses ||= Set.new) << klass
        klass.instance_variable_set(
          '@attributes',
          attributes.each_with_object({}) do |(key, value), hash|
            hash[key] = value.each_with_object({}) do |(k, v), h|
              h[k] = Marshal.load(Marshal.dump(v)) rescue v&.dup
            end
          end
        )
        klass.instance_variable_set('@after_set_callbacks', after_set_callbacks.dup)
        klass.instance_variable_set('@allow_dynamic_attributes', allow_dynamic_attributes)
        klass.instance_variable_set('@ignore_nil_default_values', ignore_nil_default_values)
      end

      # registers an after_set callback
      #
      # @param block [Proc] Proc to call after each set
      # @return [Proc] added proc
      def after_set(block)
        raise TypeError.new("Expected Proc, got #{block.class}") unless block.is_a? Proc
        after_set_callbacks.push(block)
      end
    
      # registers an NONE REQUIRED attribute
      #
      # @param attribute_name [Object] see ATTRIBUTE_CLASSES
      # @param options [Hash{Symbol}]
      # @return [Class] class where attribute was added
      def attribute?(attribute_name, options = {})
        options = options.merge({required: false})
        register_attribute(attribute_name, options)
      end
    
      # registers an REQUIRED attribute
      #
      # @param attribute_name [Object] see ATTRIBUTE_CLASSES
      # @param options [Hash{Symbol}]
      # @return [Class] class where attribute was added
      def attribute(attribute_name, options = {})
        options = options.merge({required: true})
        register_attribute(attribute_name, options)
      end
  
      # updates or registers an attribute
      #
      # @param attribute_name [Object] see ATTRIBUTE_CLASSES
      # @param options [Hash{Symbol}]
      # @return [Class] class where attribute was added
      def update_attribute(attribute_name, options = {})
        options = (attributes[attribute_name] || {}).merge(options)
        register_attribute(attribute_name, options)
      end
  
      # unregisters an attribute
      #
      # @param attribute_name [Object] see ATTRIBUTE_CLASSES
      # @return [Hash] Hash of remaining attributes
      def remove_attribute(attribute_name)
        instance_variable_set('@attributes', attributes.reject{|k,v| k == attribute_name})
      end
    
      # The actual attribute registration method
      #
      # @param attribute_name [Object] see ATTRIBUTE_CLASSES
      # @param options [Hash{Symbol}]
      # @return [Class] class where attribute was added
      def register_attribute(attribute_name, options)
        unless ATTRIBUTE_CLASSES.include?(attribute_name.class)
          raise TypeError.new("attribute_name must be a #{ATTRIBUTE_CLASSES.join(', ')}. Got: #{attribute_name.class}")
        end
        
        attributes[attribute_name] = options
        self
      end

      # Check to see if the specified attribute has been defined.
      #
      # @param name [Symbol] name of attribute
      # @return [Boolean]
      def has_attribute?(name)
        !attributes[name].nil?
      end
    
      # Check to see if the specified attribute is required.
      #
      # @param name [Symbol] name of attribute
      # @return [Boolean]
      def attr_required?(name)
        attributes.dig(name, :required) == true
      end
    end

    module InstanceMethods

      # You may initialize with an attributes hash
      # 
      # @param [Hash, Object] init_value
      # @param [Proc] preinit_proc, allows custom initialization
      # @param [Array<Symbol>] skip_required_attrs
      def initialize(init_value = {}, options = {})
        @skip_required_attrs = options[:skip_required_attrs] || []

        # allow some custom initialization with a proc
        options[:preinit_proc].call(self) if options[:preinit_proc]
        
        # iterate init_value and set all values
        if init_value.respond_to?(:each_pair)
          set_defaults(init_value)
          init_value.each do |att, value|
            self.[]=(
              att,
              value,
              skip_after_set_callbacks: true
            )
          end

          call_after_set_callbacks(nil)

          # self.default = init_value.default if init_value.default
          # self.default_proc = init_value.default_proc if init_value.default_proc
        else
          super(init_value)
        end
      end

      # Gets attribute definition from owner class
      #
      # @param name [Symbol] name of attribute
      # @return [Hash|Nil] definition of the attribute
      def klass_attribute(name)
        self.class.attributes[name]
      end
  
      # Gets all definitions from owner class
      #
      # @return [Hash] definition of all attribute
      def klass_attributes
        self.class.attributes
      end
    
      # run the following validations to an attribute:
      #
      # - if required and present
      #
      # @param [] name attribute
      # @param [] value allow to pass it if already available
      # @return [Nil]
      def validate_attribute!(name, value=nil)
        # prop = klass_attribute(name)
        value = value || self[name]
        if value.nil? && attr_required?(name)
          raise SuperHash::Exceptions::PropertyError, "The attribute '#{name}' is required"
        end
      end
    
      # # Retrieve a value from a key
      # #
      # # @param [Symbol] attribute
      # def [](attribute)
      #   super(attribute)
      # end
    
      # Sets a value. The attribute must be valid unless one of the following:
      #
      # - @allow_dynamic_attributes is true
      # - skip_validate_attribute is passed as true
      #
      # @todo for some reason the returned value is the passed value even thought it is not returned
      # 
      # @param [Symbol] attribute, name of the attribute
      # @param [Symbol] value, name of the attribute
      # @param [Boolean] skip_validate_attribute
      # @param [Boolean] skip_after_set_callbacks
      # @return [value]
      def []=(attribute, value, skip_validate_attribute: false, skip_after_set_callbacks: false)
        # assert if value is valid
        validate_attribute!(attribute, value) unless skip_validate_attribute

        unless self.class.allow_dynamic_attributes
          assert_attribute_exists!(attribute)
        end
  
        attribute_def = klass_attribute(attribute)
        if attribute_def
          #transform value with transform
          transform = attribute_def[:transform]
          value = transform.call(attribute, value, self) if transform.is_a? Proc
  
          #transform value with type
          type = attribute_def[:type]
          value = type[value] unless type.nil?
        end
        
        super(attribute, value)
        
        call_after_set_callbacks(attribute) unless skip_after_set_callbacks
      end
  
      # Override Hash#update
      def update(*other_hashes, &block)
        other_hashes.each do |other_hash|
          update_with_single_argument(other_hash, block)
        end
        self
      end
      
      # Override Hash#merge!
      alias_method :merge!, :update
    
      private
  
        def update_with_single_argument(other_hash, block)
          other_hash.to_hash.each_pair do |key, value|
            if block && key?(key)
              value = block.call(key, self[key], value)
            end
            self[key] = value
          end
        end

        # Call all registered callbacks
        #
        # @todo wrapp #call_after_set_callbacks in #initialize inside a block that temporarily
        #   disables callbacks to prevent infinite loop
        #
        # @return [void]
        def call_after_set_callbacks(attribute)
          self.class.after_set_callbacks.each do |proc|
            instance_exec(attribute, &proc)
          end
        end
        
        # Raises `SuperHash::Exceptions::PropertyError` if attribute is not defined
        #
        # @param [Symbol] attribute
        # @return [void]
        def assert_attribute_exists!(attribute)
          unless self.class.has_attribute?(attribute)
            raise SuperHash::Exceptions::PropertyError, "The attribute '#{attribute}' is not defined for #{self.class.name}."
          end
        end
      
        # checks if an attribute is required
        #
        # @param [Symbol] attribute
        # @return [Boolean]
        def attr_required?(attribute)
          !@skip_required_attrs.include?(attribute) &&
              self.class.attr_required?(attribute)
      
          # condition = self.class.required_attributes[attribute][:condition]
          # case condition
          # when Proc   then !!instance_exec(&condition)
          # when Symbol then !!send(condition)
          # else             !!condition
          # end
        end

        # sets all default values from defined attributes
        #
        # @return [void]
        def set_defaults(hash)
          ignore_nil_default_values = self.class.ignore_nil_default_values
          
          klass_attributes.each do |name, attr_options|
            next if hash.key?(name)

            if attr_options.key?(:default) && attr_options[:type]&.default?
              raise ArgumentError.new('having both default and type default is not supported')
            end

            #set from attr_options[:default]
            default_value = if attr_options.key?(:default)
                begin
                  val = attr_options[:default].dup
                  if val.is_a?(Proc)
                    val.arity == 1 ? val.call(hash) : val.call
                  else
                    val
                  end
                rescue TypeError
                  attr_options[:default]
                end
              #set from attr_options[:type]
              elsif attr_options[:type]&.default?
                attr_options[:type][Dry::Types::Undefined]
              end
    
            next if default_value.nil? && ignore_nil_default_values && !attr_required?(name)
            hash[name] = default_value

          end
        end

    end
  
  end
end

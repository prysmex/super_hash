require_relative 'version'

module Types
  def self.included(base)
    require 'dry-types'
    include Dry.Types()
  end
end

module SuperHash
  class Hasher < ::Hash
    
    # ToDo only include if configured
    include Types
  
    # The idea of the SuperHash is to have hashes with extended
    # functionality by adding the concept of 'attributes'.
    # Attributes allow to have a powerful API for controlling
    # what data can be set and more control over how the data
    # is managed. Here is a list of all the features that the
    # SuperHash provides:
  
    # = all the power of dry-types gem for each attribute!
    # = requiring some keys to be present with error raising
    # = setting a default value to a key
    # = setting transforms for specific keys
    # = ensuring all keys are symbolized
    # = accepting only whitelisted keys
    #   - This is the default behavior, if dynamic attributes are
    #     required set @allow_dynamic_attributes to true in class
  
    # There are two basic class methods to define an attribute
    #   - attribute, defines a required attribute
    #   - attribute?, defines an optional attribute
    # Both attribute and attribute? support the following options in the options hash
  
    # * type - DryType definition for value validation, see gem docs
    # * default - Default value that can also be a proc evaluated at the instance level
    # * transform - A proc that will be evaluated at the instance level
  
    # == required and type example
    #
    #   attribute :key_name, type: Types::Hash.default({}.freeze)
    #   attribute :key_name, type: Types::String.optional
    #
    # == required with instance level Proc
    #
    #   attribute :key_name, default: ->(instance) { instance[:other_attribute] }
    #
    # == optional with instance level Proc
    #
    #   attribute? :key_name, transform: All_OF_PROC
    #
  
    # registers an after_set callback
    # @param block [Proc] Proc to call after each set
    # @return [Proc] added proc
    def self.after_set(block)
      raise TypeError.new("Expected Proc, got #{block.class}") unless block.is_a? Proc
      after_set_callbacks.push(block)
    end
  
    # registers an NONE REQUIRED attribute
    # @param attribute_name [Symbol] name of attribute
    # @param options [Hash] Symbolized hash
    # @return [Class] class where attribute was added
    def self.attribute?(attribute_name, options = {})
      options = options.merge({required: false})
      register_attribute(attribute_name, options)
    end
  
    # registers an REQUIRED attribute
    # @param attribute_name [Symbol] name of attribute
    # @param options [Hash] Symbolized hash
    # @return [Class] class where attribute was added
    def self.attribute(attribute_name, options = {})
      options = options.merge({required: true})
      register_attribute(attribute_name, options)
    end

    #updates or registers an attribute
    # @param attribute_name [Symbol] name of attribute
    # @param options [Hash] Symbolized hash
    # @return [Class] class where attribute was added
    def self.update_attribute(attribute_name, options = {})
      options = (attributes[attribute_name] || {}).merge(options)
      register_attribute(attribute_name, options)
    end

    # unregisters an attribute
    # @param attribute_name [Symbol] name of attribute
    # @return [Hash] Hash of remaining attributes
    def self.remove_attribute(attribute_name)
      instance_variable_set('@attributes', attributes.reject{|k,v| k == attribute_name})
    end
  
    # The actual attribute registration method.
    # @param attribute_name [Symbol] name of attribute
    # @param options [Hash] Symbolized hash
    # @return [Class] class where attribute was added
    def self.register_attribute(attribute_name, options)
      raise TypeError.new('attribute_name must be a symbol') unless attribute_name.is_a?(::Symbol)
      attributes[attribute_name] = options
      self
    end
  
    # class level getter for attributes
    class << self
      attr_reader :attributes
      attr_reader :after_set_callbacks
      attr_reader :allow_dynamic_attributes
      attr_reader :ignore_nil_default_values
    end
    instance_variable_set('@attributes', {})
    instance_variable_set('@after_set_callbacks', [])
    instance_variable_set('@allow_dynamic_attributes', false)
    instance_variable_set('@ignore_nil_default_values', true)
  
    # when a class in inherited from this one, add it to subclasses and
    # set instance variables
    def self.inherited(klass)
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
  
    # Check to see if the specified attribute has been defined.
    # @param name [Symbol] name of attribute
    # @return [Boolean]
    def self.has_attribute?(name)
      !attributes[name].nil?
    end
  
    # Check to see if the specified attribute is required.
    # @param name [Symbol] name of attribute
    # @return [Boolean]
    def self.attr_required?(name)
      attributes.dig(name, :required) == true
    end
  
    #allow a specific instance not to require a set of attributes
    attr_reader :options
  
    # You may initialize with an attributes hash
    def initialize(init_value = nil, options={})
      instance_variable_set('@options', options || {})

      # allow some custom initialization with a proc
      if options[:preinit_proc]
        options[:preinit_proc].call(self)
      end
      
      if init_value.is_a? ::Hash
        allow_dynamic = self.class.allow_dynamic_attributes
        set_callbacks = self.class.after_set_callbacks
        # ToDo remove this for optimal performance
        init_value = SuperHash::DeepKeysTransform.symbolize_recursive(init_value)
  
        #set init_value
        init_value.each do |att, value|
          self.[]=(att, value, true, allow_dynamic, set_callbacks)
        end
      end

      # set defaults
      ignore_nil_default_values = self.class.ignore_nil_default_values
      klass_attributes.each do |name, options|
        next if self.key?(name)
        if options.key?(:default) && options[:type]&.default?
          raise ArgumentError.new('having both default and type default is not supported')
        end
        #set from options[:default]
        default_value = if options.key?(:default)
          begin
            val = options[:default].dup
            if val.is_a?(Proc)
              val.arity == 1 ? val.call(self) : val.call
            else
              val
            end
          rescue TypeError
            options[:default]
          end
        #set from options[:type]
        elsif options[:type]&.default?
          options[:type][Dry::Types::Undefined]
        end
        self[name] = default_value unless default_value.nil? && !attr_required?(name) && ignore_nil_default_values
      end

      super(init_value) unless init_value.is_a? ::Hash
  
      validate_all_attributes!
    end

    # Gets attribute definition from owner class
    # @param name [Symbol] name of attribute
    # @return [Hash|Nil] definition of the attribute
    def klass_attribute(name)
      self.class.attributes[name]
    end

    # Gets all definitions from owner class
    # @return [Hash] definition of all attribute
    def klass_attributes
      self.class.attributes
    end
    
    # runs validate_attribute for all attributes
    # @return [Hash] definition of all attribute
    def validate_all_attributes!
      klass_attributes.each do |name, options|
        validate_attribute!(name)
      end
    end
  
    # run the following validations to an attribute:
    #   - if required and present
    # @return [Nil]
    def validate_attribute!(name, value=nil)
      # prop = klass_attribute(name)
      value = value || self[name]
      if value.nil? && attr_required?(name)
        raise SuperHash::Exceptions::PropertyError, "The attribute '#{name}' is required"
      end
    end
  
    # Retrieve a value
    # ToDo: verify this logic
    def [](attribute)
      value = super(attribute)
      # If the value is a lambda, proc, or whatever answers to call, eval the thing!
      if value.is_a? Proc
        self[attribute] = value.call # Set the result of the call as a value
      else
        yield value if block_given?
        value
      end
    end
  
    # Set a value. Only works on pre-existing attributes,
    # unless @allow_dynamic_attributes is true.
    def []=(attribute, value, skip_validate_attribute = nil, allow_dynamic_attributes = nil, after_set_callbacks=nil)
      if !attribute.is_a? ::Symbol #15% performance loss
        raise TypeError.new('only symbols are supported as attributes')
      end
      
      validate_attribute!(attribute, value) unless skip_validate_attribute

      unless allow_dynamic_attributes || self.class.allow_dynamic_attributes
        assert_attribute_exists!(attribute)
      end

      attribute_def = klass_attribute(attribute)
      if attribute_def
        #transform value with transform
        transform = attribute_def[:transform]
        value = transform.call(self, value, attribute) if transform.is_a? Proc

        #transform value with type
        type = attribute_def[:type]
        value = type[value] unless type.nil?
      end
      
      super(attribute, value)
      
      (after_set_callbacks || self.class.after_set_callbacks).each do |proc|
        instance_exec(attribute, value, &proc)
      end
    end
  
    private
  
    def assert_attribute_exists!(attribute)
      unless self.class.has_attribute?(attribute)
        raise SuperHash::Exceptions::PropertyError, "The attribute '#{attribute}' is not defined for #{self.class.name}."
      end
    end
  
    def attr_required?(attribute)
      !(options[:skip_required_attrs] || []).include?(attribute) &&
      self.class.attr_required?(attribute)
  
      # condition = self.class.required_attributes[attribute][:condition]
      # case condition
      # when Proc   then !!instance_exec(&condition)
      # when Symbol then !!send(condition)
      # else             !!condition
      # end
    end
  
  end
  
end

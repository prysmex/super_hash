require_relative 'version'
require 'dry-types'

#include support for DryTypes
module Types
  include Dry.Types()
end

module SuperHashExceptions
  class PropertyError < StandardError
    def initialize(msg='')
      super(msg)
    end
  end
end

class Hash
  def bury *args
    if args.count < 2
      raise ArgumentError.new('2 or more arguments required')
    elsif args.count == 2
      self[args[0]] = args[1]
    else
      arg = args.shift
      self[arg] = {} unless self[arg]
      self[arg].bury(*args) unless args.empty?
    end
    self
  end
end


module SuperHash

  #module for symbolizing hash keys recursively
  module DeepKeysTransform

    def self.deep_transform_keys(hash, &block)
      {}.tap do |h|
        hash.each do |key, value|
          new_key = block_given? ? block.call(key) : key
          h[new_key] = map_value(value, &block)
        end
      end
    end

    def self.map_value(thing, &block)
      case thing
      when Hash
        deep_transform_keys(thing, &block)
      when Array
        thing.map { |v| map_value(v, &block) }
      else
        thing
      end
    end

    def self.symbolize_recursive(hash)
      deep_transform_keys(hash) do |key|
        key.to_sym
      end
    end

    def self.stringify_recursive(hash)
      deep_transform_keys(hash) do |key|
        key.to_s
      end
    end
  end

  class Hasher < ::Hash

    include Types
    # include SuperHashExceptions
  
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
  
    #registers an after_set callback
    def self.after_set(block)
      after_set_callbacks.push(block)
    end
  
    #registers an none required attribute
    def self.attribute?(attribute_name, options = {})
      options = options.merge({required: false})
      _register_attribute(attribute_name, options)
    end
  
    #registers a required attribute
    def self.attribute(attribute_name, options = {})
      options = options.merge({required: true})
      _register_attribute(attribute_name, options)
    end

    #updates or registers an attribute
    def self.update_attribute(attribute_name, options = {})
      options = (attributes[attribute_name] || {}).merge(options)
      _register_attribute(attribute_name, options)
    end
  
    #The actual attribute registration method.
    def self._register_attribute(attribute_name, options)
      attributes[attribute_name] = options
      #Ensure subclasses also register the attribute
      if defined? @subclasses
        if options[:required]
          @subclasses.each{ |klass| klass.attribute(attribute_name, options) }
        else
          @subclasses.each{ |klass| klass.attribute?(attribute_name, options) }
        end
      end
      self
    end
  
    #class level getter for attributes
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
      klass.instance_variable_set('@attributes', attributes.dup)
      klass.instance_variable_set('@after_set_callbacks', after_set_callbacks.dup)
      klass.instance_variable_set('@allow_dynamic_attributes', allow_dynamic_attributes)
      klass.instance_variable_set('@ignore_nil_default_values', ignore_nil_default_values)
    end
  
    # Check to see if the specified attribute has been defined.
    def self.has_attribute?(name)
      !attributes.find{|prop, options| prop == name}.nil?
    end
  
    # Check to see if the specified attribute is required.
    def self.attr_required?(name)
      !attributes.find{|prop, options| prop == name && options[:required]}.nil?
    end
  
    #allow a specific instance not to require a set of attributes
    attr_reader :options
  
    # You may initialize with an attributes hash
    def initialize(init_value = nil, options={}, &block)
      instance_variable_set('@options', options || {})

      if options[:preinit_proc]
        options[:preinit_proc].call(self)
      end
      
      if init_value.is_a? ::Hash
        init_value = SuperHash::DeepKeysTransform.symbolize_recursive(init_value)

        #set init_value
        init_value.each do |att, value|
          self[att] = value
        end

        #set defaults
        self.class.attributes.each do |name, options|
          next if init_value.key?(name)
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
          self[name] = default_value unless default_value.nil? && !attr_required?(name) && self.class.ignore_nil_default_values
        end

      else
        super(init_value, &block)
      end

      super(&block)
  
      validate_all_attributes!
    end
    
    def validate_all_attributes!
      self.class.attributes.each do |name, options|
        validate_attribute!(name)
      end
    end
  
    #run the following validations to an attribute:
    # TODO maybe other validations may apply?
    # 1) required
    def validate_attribute!(name, value=nil)
      prop = self.class.attributes.find{|prop, options| prop == name }
      name = prop[0]
      value = value || self[name]
      # options = prop[1]
      if value.nil? && attr_required?(name)
        raise SuperHashExceptions::PropertyError, "The attribute '#{name}' is required"
      end
    end
  
    # Retrieve a value
    def [](attribute)
      # assert_attribute_exists! attribute
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
    def []=(attribute, value)
      if !attribute.is_a? ::Symbol
        raise ArgumentError.new('only symbols are supported as attributes')
      end
  
      should_run_logic = if self.class.allow_dynamic_attributes
        self.class.has_attribute?(attribute)
      else
        true
      end
  
      if should_run_logic
        assert_attribute_exists! attribute
        validate_attribute!(attribute, value)
  
        #transform value with transform
        transform = self.class.attributes[attribute][:transform]
        if !transform.nil?
          if transform.is_a?(Proc)
            value = transform.call(self, value, attribute)
          end
        end
        #transform value with type
        type = self.class.attributes[attribute][:type]
        if !type.nil?
          value = type[value]
        end
      end
      
      super(attribute, value)
  
      self.class.after_set_callbacks.each{|proc| instance_exec(attribute, value, &proc)}
    end
  
    private
  
    def assert_attribute_exists!(attribute)
      unless self.class.has_attribute?(attribute)
        raise SuperHashExceptions::PropertyError, "The attribute '#{attribute}' is not defined for #{self.class.name}."
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

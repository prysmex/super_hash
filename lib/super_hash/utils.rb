module SuperHash

  #
  # Include this in a class to support calling these methods on instance level
  #
  module Helpers

    def bury(*args)
      Helpers.bury(self, *args)
    end

    def flatten_to_root(**args, &)
      Helpers.flatten_to_root(self, **args, &)
    end

  end

  #
  # Contains useful utility functions
  #
  module Utils

    # Deeply sets a value on a defined path
    #
    # @param [Hash|Array] obj to bury value into
    # @param [] *args list of arguments, last argument is the value to set and all previous define the path
    #
    # @return [Hash] mutated obj
    def self.bury(obj, *args)
      if args.count < 2
        raise ArgumentError.new('3 or more arguments required')
      elsif args.count == 2
        obj[args[0]] = args[1]
      else
        arg = args.shift
        obj[arg] = {} unless obj[arg]
        bury(obj[arg], *args) unless args.empty?
      end

      obj
    end

    # Deeply flattens an hash. You can use the `flatten_arrays` param to allow arrays to be flattened
    #
    # @param [Hash, Array] object must respond to each_pair or to_ary
    # @param [Boolean] flatten_arrays
    # @param [String] join_with
    # @param [:to_sym,:to_s] key_method
    # &block if passed and returns false when iterating a Hash, execution is halted
    #
    # @return [Hash] <description>
    def self.flatten_to_root(object, flatten_arrays: false, join_with: '.', key_method: :to_sym, &block)
      unless object.respond_to?(:each_pair) || object.respond_to?(:to_ary)
        raise TypeError.new("must respond to each_pair or to_ary, got #{object.class}")
      end

      if object.respond_to?(:each_pair)
        object.each_with_object({}) do |(key, value), hash|
          set_values_to_hash(key, value, hash, flatten_arrays, join_with, key_method, &block)
        end
      elsif object.respond_to?(:to_ary)
        object.each_with_object({}).with_index do |(value, hash), index|
          set_values_to_hash(index, value, hash, flatten_arrays, join_with, key_method, &block)
        end
      end
    end

    # called by flatten_to_root, used to reduce code
    def self.set_values_to_hash(key_or_index, value, hash, flatten_arrays, join_with, key_method, &block) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists
      valid_type = value.respond_to?(:each_pair) || (value.respond_to?(:to_ary) && flatten_arrays)
      should_continue = !block_given? || !value.respond_to?(:each_pair) || yield(value)

      if should_continue && valid_type && !value.empty?
        flatten_to_root(value, flatten_arrays:, join_with:, &block).map do |flat_k, v|
          hash["#{key_or_index}#{join_with}#{flat_k}".public_send(key_method)] = v
        end
      else
        hash[key_or_index.to_s.public_send(key_method)] = value
      end
    end

  end

end
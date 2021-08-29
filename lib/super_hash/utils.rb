module SuperHash

  #
  # Include this in a class to support calling these methods on instance level
  #
  module Helpers

    def bury(*args)
      Helpers.bury(self, *args)
    end

    def flatten_to_root(**args, &block)
      Helpers.flatten_to_root(self, **args, &block)
    end

  end

  #
  # Contains useful utility functions
  #
  module Utils
    
    # Deeply sets a value on a defined path
    #
    # @param [Hash] hash to bury value into
    # @param [] *args list of arguments, last argument is the value to set and all previous define the path
    #
    # @return [Hash] mutated hash
    def self.bury(hash, *args)
      raise TypeError.new("first argument must respond to each_pair, got #{hash.class}") unless hash.respond_to?(:each_pair)
      if args.count < 2
        raise ArgumentError.new('3 or more arguments required')
      elsif args.count == 2
        hash[args[0]] = args[1]
      else
        arg = args.shift
        hash[arg] = {} unless hash[arg]
        bury(hash[arg], *args) unless args.empty?
      end
      hash
    end
  
    # Deeply flattens an hash. You can use the `flatten_arrays` param to allow arrays to be flattened
    #
    # @param [Hash, Array] object must respond to each_pair or to_ary
    # @param [Boolean] flatten_arrays <description>
    # @param [<Type>] &block if passed and returns false when iterating a Hash, execution is halted
    #
    # @return [Hash] <description>
    def self.flatten_to_root(object, flatten_arrays: false, join_with: '.', &block)
      raise TypeError.new("must respond to each_pair or to_ary, got #{object.class}") unless object.respond_to?(:each_pair) || object.respond_to?(:to_ary)

      if object.respond_to?(:each_pair)
        object.each_with_object({}) do |(key, value), hash|
          set_values_to_hash(key, value, hash, flatten_arrays, join_with, &block)
        end
      elsif object.respond_to?(:to_ary)
        object.each_with_object({}).with_index do |(value, hash), index|
          set_values_to_hash(index, value, hash, flatten_arrays, join_with, &block)
        end
      end
    
    end

    private

    # called by flatten_to_root, used to reduce code
    def self.set_values_to_hash(key_or_index, value, hash, flatten_arrays, join_with, &block)
      valid_type = value.respond_to?(:each_pair) || (value.respond_to?(:to_ary) && flatten_arrays)
      should_continue = !block_given? || !value.respond_to?(:each_pair) || yield(value)

      if should_continue && valid_type && !value.empty?
        flatten_to_root(value, {flatten_arrays: flatten_arrays, join_with: join_with}, &block).map do |flat_k, v|
          hash["#{key_or_index}#{join_with}#{flat_k}".to_sym] = v
        end
      else
        hash["#{key_or_index}".to_sym] = value
      end
    end

  end
  
end
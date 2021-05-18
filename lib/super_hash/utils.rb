module SuperHash

  module Helpers

    def bury(*args)
      Helpers.bury(self, *args)
    end

    def flatten_to_root
      Helpers.flatten_to_root(self)
    end

    def deep_transform_keys(&block)
      DeepKeysTransform.deep_transform_keys(self, &block)
    end

    def symbolize_recursive
      DeepKeysTransform.symbolize_recursive(self)
    end
    
    def stringify_recursive
      DeepKeysTransform.stringify_recursive(self)
    end
    
  end

  module Utils
    
    def self.bury(hash, *args)
      raise TypeError.new("first argument must be a Hash to mutate or should respond to .[]=, got #{hash.class}") unless hash.is_a?(Hash) || hash.respond_to?(:[]=)
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
  
    def self.flatten_to_root(object, flatten_arrays: false)
      raise TypeError.new("must be a Hash or Array, got #{object.class}") unless [Hash, Array].include?(object.class)

      case object
      when Hash
        object.each_with_object({}) do |(key, value), hash|
          if (value.is_a?(Hash) || (value.is_a?(Array) && flatten_arrays)) && !value.empty?
            flatten_to_root(value, {flatten_arrays: flatten_arrays}).map do |flat_k, v|
              hash["#{key}.#{flat_k}".to_sym] = v
            end
          else
            hash["#{key}".to_sym] = value
          end
        end
      when Array
        object.each_with_object({}).with_index do |(value, hash), index|
          if (value.is_a?(Hash) || (value.is_a?(Array) && flatten_arrays)) && !value.empty?
            flatten_to_root(value, {flatten_arrays: flatten_arrays}).map do |flat_k, v|
              hash["#{index}.#{flat_k}".to_sym] = v
            end
          else
            hash["#{index}".to_sym] = value
          end
        end
      end
    
    end

  end

  #module for symbolizing hash keys recursively
  module DeepKeysTransform

    def self.deep_transform_keys(hash, &block)
      {}.tap do |h|
        hash.each do |key, value|
          new_key = block_given? ? block.call(key) : key
          h[new_key] = transform_value(value, &block)
        end
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

    private

    def self.transform_value(thing, &block)
      case thing
      when Hash
        deep_transform_keys(thing, &block)
      when Array
        thing.map { |v| transform_value(v, &block) }
      else
        thing
      end
    end

  end
  
end
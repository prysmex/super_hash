module SuperHash

  module Helpers

    def bury(*args)
      Helpers.bury(self, *args)
    end

    def flatten_to_root
      Helpers.bury(self)
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
      raise TypeError.new("first argument must be a Hash to mutate, got #{hash.class}") unless hash.is_a?(Hash)
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
  
    def self.flatten_to_root(hash)
      raise TypeError.new("must be a Hash, got #{hash.class}") unless hash.is_a?(Hash)
      hash.each_with_object({}) do |(k, v), h|
        if v.is_a? Hash
          flatten_to_root(v).map do |h_k, h_v|
            h["#{k}.#{h_k}".to_sym] = h_v
          end
        else
          h[k] = v
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
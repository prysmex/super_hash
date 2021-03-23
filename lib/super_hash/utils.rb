module SuperHash

  module Helpers
    
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
  
end
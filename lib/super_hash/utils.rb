module SuperHash

  module Helpers

    def bury(*args)
      Helpers.bury(self, *args)
    end

    def flatten_to_root
      Helpers.flatten_to_root(self)
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
  
    def self.flatten_to_root(object, flatten_arrays: false, &block)
      raise TypeError.new("must be a Hash or Array, got #{object.class}") unless [Hash, Array].include?(object.class)

      block_proc = Proc.new do |key_or_index, value, hash|
        if (!block_given? || !value.is_a?(Hash) || yield(value)) && (value.is_a?(Hash) || (value.is_a?(Array) && flatten_arrays)) && !value.empty?
          flatten_to_root(value, {flatten_arrays: flatten_arrays}, &block).map do |flat_k, v|
            hash["#{key_or_index}.#{flat_k}".to_sym] = v
          end
        else
          hash["#{key_or_index}".to_sym] = value
        end
      end

      case object
      when Hash
        object.each_with_object({}) do |(key, value), hash|
          block_proc.call(key, value, hash)
        end
      when Array
        object.each_with_object({}).with_index do |(value, hash), index|
          block_proc.call(index, value, hash)
        end
      end
    
    end

  end
  
end
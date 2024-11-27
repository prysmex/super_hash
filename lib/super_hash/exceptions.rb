module SuperHash
  module Exceptions
    # Used for validating attributes
    class AttributeError < StandardError
      def initialize(msg = '')
        super
      end
    end
  end
end
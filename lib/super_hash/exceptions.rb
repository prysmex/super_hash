module SuperHash
  module Exceptions
    class PropertyError < StandardError
      def initialize(msg='')
        super(msg)
      end
    end
  end
end
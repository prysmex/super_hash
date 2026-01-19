require 'test_helper'

module HasherTestMethods
  def setup
    @new_hasher_class = Object.const_set(:NewHasher, Class.new(Hash))
    @new_hasher_class.include(SuperHash::Hasher)
  end

  def teardown
    Object.send(:remove_const, 'NewHasher')
  end
end

# Class level
class HasherClassTest < Minitest::Test
  include HasherTestMethods
  include HasherClassBehavior
end

# Instance level
class HasherInstanceTest < Minitest::Test
  include HasherTestMethods
  include HasherInstanceBehavior
end
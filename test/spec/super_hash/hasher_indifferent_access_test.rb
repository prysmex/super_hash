require 'test_helper'

module HasherIndifferentAccessTestMethods
  def setup
    @new_hasher_class = Object.const_set(:NewHasher, Class.new(ActiveSupport::HashWithIndifferentAccess))
    @new_hasher_class.include(SuperHash::Hasher)
    @new_hasher_class.include(SuperHash::Hasher::IndifferentAccess)
  end

  def teardown
    Object.send(:remove_const, 'NewHasher')
  end
end

# Class level
class HasherIndifferentAccessClassTest < Minitest::Test
  include HasherIndifferentAccessTestMethods
  include HasherClassBehavior
end

# Instance level level
class HasherIndifferentAccessInstanceTest < Minitest::Test
  include HasherIndifferentAccessTestMethods
  include HasherInstanceBehavior

  def test_raises_on_symbol_attribute
    assert_raises(TypeError) { @new_hasher_class.attribute :name }
  end

  def test_require_allows_symbol_data
    @new_hasher_class.attribute 'name'

    assert_raises(::SuperHash::Exceptions::AttributeError) { @new_hasher_class.new }
    @new_hasher_class.new({name: 'yoda'})
  end

  def test_init_options_are_stored_and_passed_in_dup
    @new_hasher_class.attribute? 'name', {
      default: ->(_data) { 'John' }
    }

    opts = { my_option: 1 }
    hasher = @new_hasher_class.new({}, opts)

    assert_equal(opts, hasher.init_options)
    dupped = hasher.dup

    assert_equal(opts, dupped.init_options)
  end
end
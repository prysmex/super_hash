require "test_helper"

module HasherTestMethods
  def setup
    @new_hasher_class = Object.const_set('NewHasher', Class.new(Hash))
    @new_hasher_class.include(SuperHash::Hasher)
  end

  def teardown
    Object.send(:remove_const, 'NewHasher')
  end
end


class HasherClassTest < Minitest::Test
  include HasherTestMethods

  def test_defaults
    assert_equal false, @new_hasher_class.allow_dynamic_attributes
    assert_equal 0, @new_hasher_class.attributes.size
    assert_equal true, @new_hasher_class.ignore_nil_default_values
    assert_equal 0, @new_hasher_class.after_set_callbacks.size
  end

  def test_raise_error_if_attribute_type_not_whitelisted
    assert_raises(::TypeError) { @new_hasher_class.attribute({}) }
  end

  def test_can_define_required_attribute
    @new_hasher_class.attribute :'name'
    refute_nil @new_hasher_class.attributes[:name]
    assert_equal true, @new_hasher_class.has_attribute?(:name)
    assert_equal true, @new_hasher_class.attributes[:name][:required]
    assert_equal true, @new_hasher_class.attr_required?(:name)
  end

  def test_can_define_optional_attribute
    @new_hasher_class.attribute? :'name'
    refute_nil @new_hasher_class.attributes[:name]
    assert_equal true, @new_hasher_class.has_attribute?(:name)
    assert_equal false, @new_hasher_class.attributes[:name][:required]
    assert_equal false, @new_hasher_class.attr_required?(:name)
  end

  def test_can_update_attribute
    @new_hasher_class.attribute :'name'
    @new_hasher_class.update_attribute :'name', {required: false}
    assert_equal false, @new_hasher_class.attr_required?(:name)
  end

  def test_can_remove_attribute
    @new_hasher_class.attribute :'name'
    @new_hasher_class.remove_attribute :'name'
    assert_equal false, @new_hasher_class.has_attribute?(:name)
  end
  
  def test_subclass_copies_configuration
    NewHasher.attribute :name
    NewHasher.instance_variable_set('@allow_dynamic_attributes', true)
    NewHasher.instance_variable_set('@ignore_nil_default_values', false)

    other_hasher_klass = Object.const_set('NewHasher2', Class.new(NewHasher))
    
    assert_equal true, other_hasher_klass.has_attribute?(:name)
    assert_equal true, other_hasher_klass.allow_dynamic_attributes
    assert_equal false, other_hasher_klass.ignore_nil_default_values

    Object.send(:remove_const, 'NewHasher2')
  end

end


class HasherInstanceTest < Minitest::Test

  include HasherTestMethods

  DOUBLER_PROC = ->(attribute, value, instance) {
    value * 2
  }

  ####################
  #dynamic properties#
  ####################

  def test_raises_error_when_unknown_key_and_dynamic_not_allowed
    assert_raises(::SuperHash::Exceptions::PropertyError) { @new_hasher_class.new({hello: 1}) }
    assert_raises(::SuperHash::Exceptions::PropertyError) { @new_hasher_class.new()[:hello] = 1 }
    assert_raises(::SuperHash::Exceptions::PropertyError) { @new_hasher_class.new().merge!(hello: 1) }
    assert_raises(::SuperHash::Exceptions::PropertyError) { @new_hasher_class.new().update(hello: 1) }
  end

  def test_allow_to_get_unknown_keys
    assert_nil @new_hasher_class.new()[:hello]
  end

  def test_may_allow_dynamic_properties
    @new_hasher_class.instance_variable_set('@allow_dynamic_attributes', true)

    # init
    assert_equal 1, @new_hasher_class.new({hello: 1})[:hello]

    # set
    instance =  @new_hasher_class.new()
    instance[:hello] = 1
    assert_equal 1, instance[:hello]

    assert_equal 1, @new_hasher_class.new().merge!(hello: 1)[:hello]
    assert_equal 1, @new_hasher_class.new().update(hello: 1)[:hello]
  end

  #####################
  #required properties#
  #####################

  def test_raise_error_when_missing_required_key
    @new_hasher_class.attribute :'name'
    assert_raises(::SuperHash::Exceptions::PropertyError) { @new_hasher_class.new() }
  end

  def test_property_may_be_optional
    @new_hasher_class.attribute? :'name'
    assert_empty @new_hasher_class.new()
  end

  #######################
  #attribute validations#
  #######################

  def test_attribute_type_is_valid
    @new_hasher_class.attribute :'name', type: ::Types::String
    refute_empty @new_hasher_class.new(name: 'John')
  end

  def test_attribute_type_is_invalid
    @new_hasher_class.attribute :'name', type: ::Types::String
    assert_raises(::Dry::Types::ConstraintError) { @new_hasher_class.new(name: 1) }
  end

  ################
  #default values#
  ################
  
  def test_default_values_are_overridable
    @new_hasher_class.attribute :'name', {
      default: ->(data) { 'John' }
    }
    assert_equal 'Yoda', @new_hasher_class.new({name: 'Yoda'})[:name]
  end

  def test_can_define_default_values
    @new_hasher_class.attribute :'name', {
      default: ->(data) { 'John' }
    }
    assert_equal 'John', @new_hasher_class.new()[:name]
  end

  def test_can_define_default_values_from_other_values
    @new_hasher_class.attribute :'name'
    @new_hasher_class.attribute :'nickname', {
      default: ->(data) { data[:name] }
    }
    assert_equal 'John', @new_hasher_class.new(name: 'John')[:nickname]
  end

  def test_can_define_default_values_with_dry_types
    @new_hasher_class.attribute :'name', {
      type: Types::String.default('Yoda'.freeze)
    }
    assert_equal 'Yoda', @new_hasher_class.new()[:name]
  end

  ############
  #transforms#
  ############

  def test_transform_value
    @new_hasher_class.attribute :'name'
    @new_hasher_class.attribute :'age', {
      transform: DOUBLER_PROC
    }
    assert_equal 200, @new_hasher_class.new({name: 'Yoda', age: 100})[:age]
  end

  def test_transform_from_default_value
    @new_hasher_class.attribute :'age', {
      default: 100,
      transform: DOUBLER_PROC
    }
    assert_equal 200, @new_hasher_class.new()[:age]
  end

  ###########
  #callbacks#
  ###########

  def test_after_set_callback
    @new_hasher_class.attribute :'main_hash'
    @new_hasher_class.attribute? :'main_hash_mirror'
    @new_hasher_class.after_set ->(attr_name) {
      self[:main_hash_mirror] = self[:main_hash] if attr_name.nil? || attr_name == :main_hash
    }
    instance = @new_hasher_class.new({main_hash: {some_data: 1}})

    assert_equal 1, instance.dig(:main_hash_mirror, :some_data)
  end

end
module HasherInstanceBehavior
  DOUBLER_PROC = lambda { |_attribute, value, _instance|
    value * 2
  }

  # Currently it does mutate it
  # def test_does_not_mutate_origin
  #   value = {}
  #   @new_hasher_class.attribute 'name', {
  #     default: ->(_data) { 'John' }
  #   }

  #   @new_hasher_class.new(value)

  #   assert_empty value
  # end

  def test_dup_does_not_re_add_defaults
    @new_hasher_class.attribute? 'name', {
      default: ->(_data) { 'John' }
    }

    hasher = @new_hasher_class.new
    hasher.delete('name')

    assert_empty(hasher.to_hash)
    assert_empty(hasher.dup.to_hash)
  end

  # bug in ActiveSupport::HashWithIndifferentAccess /w activesupport 6.1.4.1
  def test_to_hash_does_not_re_add_defaults
    @new_hasher_class.attribute? 'name', {
      default: ->(_data) { 'John' }
    }

    value = {'name' => nil}
    hasher = @new_hasher_class.new(value)

    assert_equal(value, hasher.to_hash)
    hasher.delete('name')

    assert_empty(hasher.to_hash)
  end

  ####################
  # dynamic properties#
  ####################

  def test_raises_error_when_unknown_key_and_dynamic_not_allowed
    assert_raises(::SuperHash::Exceptions::AttributeError) { @new_hasher_class.new({'hello' => 1}) }
    assert_raises(::SuperHash::Exceptions::AttributeError) { @new_hasher_class.new['hello'] = 1 }
    assert_raises(::SuperHash::Exceptions::AttributeError) { @new_hasher_class.new.merge!('hello' => 1) }
    assert_raises(::SuperHash::Exceptions::AttributeError) { @new_hasher_class.new.update('hello' => 1) }
  end

  def test_allow_to_get_unknown_keys
    assert_nil @new_hasher_class.new['hello']
  end

  # def test_raises_error_when_hasher_is_passed
  #   assert_raises(StandardError) { @new_hasher_class.new(@new_hasher_class.new) }
  # end

  def test_may_allow_dynamic_properties
    @new_hasher_class.instance_variable_set(:@allow_dynamic_attributes, true)

    # init
    assert_equal 1, @new_hasher_class.new({'hello' => 1})['hello']

    # set
    instance = @new_hasher_class.new
    instance['hello'] = 1

    assert_equal 1, instance['hello']

    assert_equal 1, @new_hasher_class.new.merge!('hello' => 1)['hello']
    assert_equal 1, @new_hasher_class.new.update('hello' => 1)['hello']
  end

  #####################
  # required properties#
  #####################

  def test_raise_error_when_missing_required_key
    @new_hasher_class.attribute 'name'
    assert_raises(::SuperHash::Exceptions::AttributeError) { @new_hasher_class.new }
    @new_hasher_class.new({'name' => 'Yoda'})
  end

  def test_allow_ignoring_required_key
    @new_hasher_class.attribute 'name'
    assert_raises(::SuperHash::Exceptions::AttributeError) { @new_hasher_class.new({}, {skip_required_attrs: ['other']}) }
    @new_hasher_class.new({}, {skip_required_attrs: ['name']})
  end

  def test_property_may_be_optional
    @new_hasher_class.attribute? 'name'

    assert_empty @new_hasher_class.new
  end

  def test_delete_required_property
    @new_hasher_class.attribute 'name'

    hasher = @new_hasher_class.new({'name' => 'Yoda'})
    hasher.delete('name')
    hasher.dup # must not raise error
  end

  #######################
  # attribute validations#
  #######################

  def test_attribute_type_is_valid
    @new_hasher_class.attribute 'name', type: ::Types::String

    refute_empty @new_hasher_class.new('name' => 'John')
  end

  def test_attribute_type_is_invalid
    @new_hasher_class.attribute 'name', type: ::Types::String
    assert_raises(::Dry::Types::ConstraintError) { @new_hasher_class.new('name' => 1) }
  end

  ################
  # default values#
  ################

  def test_default_values_are_overridable
    @new_hasher_class.attribute 'name', {
      default: ->(_data) { 'John' }
    }

    assert_equal 'Yoda', @new_hasher_class.new({'name' => 'Yoda'})['name']
  end

  def test_can_define_default_values
    @new_hasher_class.attribute 'name', {
      default: ->(_data) { 'John' }
    }

    assert_equal 'John', @new_hasher_class.new['name']
  end

  def test_can_define_default_values_from_other_values
    @new_hasher_class.attribute 'name'
    @new_hasher_class.attribute 'nickname', {
      default: ->(data) { data['name'] }
    }

    assert_equal 'John', @new_hasher_class.new('name' => 'John')['nickname']
  end

  def test_can_define_default_values_with_dry_types
    @new_hasher_class.attribute 'name', {
      type: Types::String.default('Yoda'.freeze)
    }

    assert_equal 'Yoda', @new_hasher_class.new['name']
  end

  ############
  # transforms#
  ############

  def test_transform_value
    @new_hasher_class.attribute 'name'
    @new_hasher_class.attribute 'age', {
      transform: DOUBLER_PROC
    }

    assert_equal 200, @new_hasher_class.new({'name' => 'Yoda', 'age' => 100})['age']
  end

  def test_transform_from_default_value
    @new_hasher_class.attribute 'age', {
      default: 100,
      transform: DOUBLER_PROC
    }

    assert_equal 200, @new_hasher_class.new['age']
  end

  ###########
  # callbacks#
  ###########

  def test_after_set_callback
    @new_hasher_class.attribute 'main_hash'
    @new_hasher_class.attribute? 'main_hash_mirror'
    @new_hasher_class.after_set lambda { |attr_name|
      self['main_hash_mirror'] = self['main_hash'] if attr_name.nil? || attr_name == 'main_hash'
    }
    instance = @new_hasher_class.new({'main_hash' => {some_data: 1}})

    assert_equal 1, instance.dig('main_hash_mirror', :some_data)
  end
end
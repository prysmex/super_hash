module HasherClassBehavior
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
    @new_hasher_class.attribute 'name'

    refute_nil @new_hasher_class.attributes['name']
    assert_equal true, @new_hasher_class.has_attribute?('name')
    assert_equal true, @new_hasher_class.attributes['name'][:required]
    assert_equal true, @new_hasher_class.attr_required?('name')
  end

  def test_can_define_optional_attribute
    @new_hasher_class.attribute? 'name'

    refute_nil @new_hasher_class.attributes['name']
    assert_equal true, @new_hasher_class.has_attribute?('name')
    assert_equal false, @new_hasher_class.attributes['name'][:required]
    assert_equal false, @new_hasher_class.attr_required?('name')
  end

  def test_can_update_attribute
    @new_hasher_class.attribute 'name'
    @new_hasher_class.update_attribute 'name', {required: false}

    assert_equal false, @new_hasher_class.attr_required?('name')
  end

  def test_can_remove_attribute
    @new_hasher_class.attribute 'name'
    @new_hasher_class.remove_attribute 'name'

    assert_equal false, @new_hasher_class.has_attribute?('name')
  end

  def test_subclass_copies_configuration
    NewHasher.attribute 'name'
    NewHasher.instance_variable_set(:@allow_dynamic_attributes, true)
    NewHasher.instance_variable_set(:@ignore_nil_default_values, false)

    other_hasher_klass = Object.const_set(:NewHasher2, Class.new(NewHasher))

    assert_equal true, other_hasher_klass.has_attribute?('name')
    assert_equal true, other_hasher_klass.allow_dynamic_attributes
    assert_equal false, other_hasher_klass.ignore_nil_default_values

    Object.send(:remove_const, 'NewHasher2')
  end
end
require 'test_helper'
require 'json'

class HelperBuryTest < Minitest::Test

  def test_bury_requires_3_args
    assert_raises(ArgumentError){ SuperHash::Utils.bury({}, true) }
  end

  def test_bury_array_argument_must_be_indices_like
    SuperHash::Utils.bury([], 0, true)
    assert_raises(TypeError){ SuperHash::Utils.bury([], 'test', true) }
    assert_raises(TypeError){ SuperHash::Utils.bury({a: []}, :a, 'test', true) }
  end

  def test_bury_complex_path
    test_path = [:'tes.yt', 'as/?df', '__.__', 7, '93.90', 9]
    value = 1
    hash = {}
    SuperHash::Utils.bury(hash, *test_path, value)
    assert_equal value, hash.dig(*test_path)
  end

  def test_bury_sibling_keys
    hash = {}

    paths = [
      [:some_data, :some_data_2, :test_1],
      [:some_data, :some_data_2, :test_2],
      [:some_data, :some_data_3, :test_3]
    ]

    paths.each_with_index do |path, i|
      SuperHash::Utils.bury(hash, *path, i)
      assert_equal i, hash.dig(*path)
    end
  end

  def test_intermediate_array
    hash = {
      a: [{b: :c}],
      d: []
    }

    paths = [
      [:a, 0, :b],
      [:a, 0, :e],
      [:a, 1, :f],
      [:d, 3],
    ]

    paths.each_with_index do |path, i|
      SuperHash::Utils.bury(hash, *path, i)
      assert_equal i, hash.dig(*path)
    end
  end

  def test_root_array
    array = []

    paths = [
      [1, :a, 3, :b]
    ]

    paths.each_with_index do |path, i|
      SuperHash::Utils.bury(array, *path, i)
      assert_equal i, array.dig(*path)
    end
  end
end

class HelperFlattenToRootTest < Minitest::Test
  def compare_jsons(a, b)
    assert_equal JSON.generate(a), JSON.generate(b)
  end

  def setup
    @example = {
      level_1_1: {
        level_2_1: {
          level_3_1: [1,2],
          level_3_2: [
            {
              level_4_1: 1
            },
            {
              level_4_2: {
                level_5_1: 1
              }
            }
          ]
        }
      }
    }
  end

  def test_flatten_to_root
    flattened = SuperHash::Utils.flatten_to_root(@example)

    expected_value = {
      :"level_1_1.level_2_1.level_3_1"=>[1, 2],
      :"level_1_1.level_2_1.level_3_2"=>[
        {:level_4_1=>1},
        {:level_4_2=>{:level_5_1=>1}}
      ]
    }

    compare_jsons(flattened, expected_value)
  end

  def test_flatten_to_root_with_flattened_arrays
    flattened = SuperHash::Utils.flatten_to_root(@example, flatten_arrays: true)

    expected_value = {
      :"level_1_1.level_2_1.level_3_1.0"=>1,
      :"level_1_1.level_2_1.level_3_1.1"=>2,
      :"level_1_1.level_2_1.level_3_2.0.level_4_1"=>1,
      :"level_1_1.level_2_1.level_3_2.1.level_4_2.level_5_1"=>1
    }
    compare_jsons(flattened, expected_value)
  end

  def test_flatten_to_root_with_custom_join
    flattened = SuperHash::Utils.flatten_to_root(@example, join_with: '|')

    expected_value = {
      :"level_1_1|level_2_1|level_3_1"=>[1, 2],
      :"level_1_1|level_2_1|level_3_2"=>[
        {:level_4_1=>1},
        {:level_4_2=>{:level_5_1=>1}}
      ]
    }

    compare_jsons(flattened, expected_value)
  end

  def test_flatten_to_root_with_block
    flattened = SuperHash::Utils.flatten_to_root(@example){ false }

    compare_jsons(flattened, @example)
  end

end
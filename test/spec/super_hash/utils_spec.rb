require 'test_helper'

class HelperTest < Minitest::Test

  def test_bury_complex
    test_path = [:'tes.yt', 'as/?df', '__.__', '93.90', 9]
    value = 1
    hash = {}
    SuperHash::Helpers.bury(hash, *test_path, value)
    assert_equal value, hash.dig(*test_path)
  end

  def test_bury_does_not_sibling_keys
    hash = {}
    path_1 = [:some_data, :test_1]
    path_2 = [:some_data, :test_2]
    SuperHash::Helpers.bury(hash, *path_1, true)
    SuperHash::Helpers.bury(hash, *path_2, true)
    assert_equal true, hash.dig(*path_1)
    assert_equal true, hash.dig(*path_2)
  end

  # def test_flatten_to_root

  #   expected_value = {
  #     :"level_1_1.level_2_1.level_3_1"=>[1, 2],
  #     :"level_1_1.level_2_1.level_3_2"=>[
  #       {:level_4_1=>1},
  #       {:level_4_2=>{:level_5_1=>1}}
  #     ]
  #   }

  #   flattened = SuperHash::Helpers.flatten_to_root({
  #     level_1_1: {
  #       level_2_1: {
  #         level_3_1: [1,2],
  #         level_3_2: [
  #           {
  #             level_4_1: 1
  #           },
  #           {
  #             level_4_2: {
  #               level_5_1: 1
  #             }
  #           }
  #         ]
  #       }
  #     }
  #   })

  #   #todo multiple asserts between expected value and flattened
  # end

end

class DeepKeysTransform < Minitest::Test


end
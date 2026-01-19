# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'super_hash'
require 'debug'
require 'json'

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/reporters'

require 'support/hasher_class_behavior'
require 'support/hasher_instance_behavior'

require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/hash/indifferent_access'

Minitest::Reporters.use!
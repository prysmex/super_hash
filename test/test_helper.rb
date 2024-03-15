# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'super_hash'
require 'debug'

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/reporters'

Minitest::Reporters.use!
require_relative 'ft-wrapper-logger'
require 'version'

require 'ft-ffi-wrapper/library'

module FT
  module Wrapper
    LOGGER.info("FT FFI Wrapper v#{FT::Wrapper::VERSION}")
  end
end
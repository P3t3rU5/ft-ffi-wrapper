require 'ft-ffi'

require_relative 'version'
require_relative 'ft-wrapper-logger'

module FT
  module Wrapper
    LOGGER.info("FT FFI Wrapper v#{FT::Wrapper::VERSION}")
  end
end
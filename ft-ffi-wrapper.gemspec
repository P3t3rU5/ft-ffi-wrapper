require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name          = 'ft-ffi-wrapper'
  s.version       = FT::Wrapper::VERSION
  s.summary       = 'FFI wrapper for FreeType API'
  s.description   = 'FFI wrapper for FreeType API.'
  s.license       = 'MIT'
  s.authors       = %w'P3t3rU5 SilverPhoenix99'
  s.email         = %w'pedro.megastore@gmail.com silver.phoenix99@gmail.com'
  s.homepage      = 'https://github.com/P3t3rU5/ft-ffi-wrapper'
  s.require_paths = %w'lib'
  s.files         = Dir['{lib/**/*.rb,lib/**/*.dll,*.md,*.txt}']
  s.add_dependency 'ft-ffi'
  s.add_development_dependency 'rspec', '~> 3.4'
  s.post_install_message = <<-eos
+----------------------------------------------------------------------------+
  Thanks for choosing FreeTypeFFIWrapper.

  ==========================================================================
  #{FT::Wrapper::VERSION} Changes:
    - First Version

  ==========================================================================

  If you find any bugs, please report them on
    https://github.com/P3t3rU5/ft-ffi-wrapper/issues

+----------------------------------------------------------------------------+
  eos
end

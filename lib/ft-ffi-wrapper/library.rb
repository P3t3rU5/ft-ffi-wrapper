require 'ft-ffi/function/library'
require 'ft-ffi-wrapper/face'

module FT
  module Wrapper
    class Library

      attr_reader :library

      def initialize
        lib_pointer = FFI::MemoryPointer.new(:pointer)
        FT.Init_FreeType(lib_pointer)
        @library = LibraryRec.new(lib_pointer.read_pointer)
        @mutex = Mutex.new

        ObjectSpace.define_finalizer(self, self.class.finalize(@library))
      end

      def self.finalize(library)
        proc do
          LOGGER.debug "releasing FT_Library #{library}..."
          FT.Done_FreeType(library)
          LOGGER.debug "released FT_Library #{library}."
        end
      end

      def new_face(filepathname, face_index = 0)
        face = nil
        synchronize { face = Face.new(self, filepathname, face_index) }
        face
      end

      def version(format: :array)
        major, minor, patch = @library[:version_major], @library[:version_minor], @library[:version_patch]
        case format
          when :array
            [major, minor, patch]
          when :string
            "#{major}.#{minor}.#{patch}"
        end
      end

      def number_of_modules
        @library[:num_modules]
      end

      def reference_count
        @library[:refcount]
      end

      def renderers
        @library[:renderers]
      end

      def current_renderer
        @library[:cur_renderer]
      end

      def auto_hinter
        @library[:auto_hinter]
      end

      def synchronize(&block)
        @mutex.synchronize(&block)
      end
    end
  end
end
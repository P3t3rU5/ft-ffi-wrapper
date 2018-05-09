module FT
  module Wrapper
    class Size
      extend LibBase

      def initialize(face)
        @face = face
        p_size = FFI::MemoryPointer.new(:pointer)
        p_face = face.instance_variable_get(@face)
        lib = face.library

        FT.New_Size(p_face, p_size)
        @size = SizeRec.new(p_size.read_pointer)

        @finalizer = { :size => @size }

        ObjectSpace.define_finalizer(self, self.class.finalize(lib, @finalizer))
      end

      def self.finalize(lib, finalizer)
        proc do
          lib.synchronize do
            size = finalizer[:size]
            if size
              puts "releasing FT_Face #{size.to_ptr}"
              FT.Done_Size(size)
              finalizer[:size] = nil
            end
          end
        end
      end

      def done
        self.class.finalize(@library, @finalizer).call
      end

    end
  end
end
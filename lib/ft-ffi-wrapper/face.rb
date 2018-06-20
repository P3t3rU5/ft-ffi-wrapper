require 'ft-ffi/function/face'
require 'ft-ffi/function/glyph_slot'
require 'ffi-additions/array'

using FFIAdditions::ArrayUtils

module FT
  module Wrapper
    class Face
      attr_reader :library, :face

      def initialize(lib, filepathname, face_index = 0)
        @library = lib # avoid gc of library

        # @face = FaceRec.new
        face_pointer = FFI::MemoryPointer.new(:pointer)
        FT.New_Face(@library.library, filepathname, face_index, face_pointer)
        @face = FaceRec.new(face_pointer.read_pointer)

        @finalizer = { face: @face }

        ObjectSpace.define_finalizer(self, self.class.finalize(lib, @finalizer))
      end

      def self.finalize(lib, finalizer)
        proc do
          lib.synchronize do
            face = finalizer[:face]
            if face
              face_ptr = face.to_ptr
              LOGGER.debug "releasing FT_Face #{face.to_ptr}..."
              FT.Done_Face(face)
              LOGGER.debug "released FT_Face #{face_ptr}."
              finalizer[:face] = nil
            end
          end
        end
      end

      def self.to_code(char)
        char.is_a?(Integer) ? char : char.ord
      end

      def char_index(char)
        code = self.class.to_code(char)
        index = FT.Get_Char_Index(@face, code)
        raise FreeTypeError, "undefined character code: #{char.inspect} (0x#{code.to_s(16)})" if index == 0
        index = FT.Get_Char_Index(@face, 0x25A1) if index == 0
        index
      end

      def done
        self.class.finalize(@library, @finalizer).call
      end

      def charmaps
        return if @face.charmaps.null?
        @charmaps ||= Array.from_pointer_of(CharMapRec, @face.charmaps, @face.num_charmaps)
      end

      def charmap=(charmap)
        return unless @charmaps.include?(charmap)
        FT.Set_Charmap(@face, charmap)
      end

      def each_char
        return enum_for(:each_char) unless block_given?

        p_gindex = FFI::MemoryPointer.new(:uint)
        charcode = FT.Get_First_Char(@face, p_gindex)
        gindex = p_gindex.read_uint
        while gindex != 0
          yield charcode, gindex
          charcode = FT.Get_Next_Char(@face, charcode, p_gindex)
          gindex = p_gindex.read_uint
        end
      end

      def each_glyph(*load_flags)
        return enum_for(:each_glyph, *load_flags) unless block_given?
        each_char { |charcode, index| yield load_glyph(index, *load_flags), charcode, index }
      end

      def kerning(left_glyph, right_glyph, mode = :DEFAULT)
        v = FT::Vector.new
        FT.Get_Kerning(@face, left_glyph, right_glyph, FT::KerningMode[mode], v)
        [v.x / 64.0, v.y / 64.0]
      end

      def glyph_slot
        @face.glyph_slot
      end

      def load_char(char, *flags)
        char = self.class.to_code(char)
        return unless char
        flags = [:DEFAULT] if flags.size == 0
        flags = flags.reduce { |a, flag| a | LoadFlag[flag] }
        FT.Load_Char(@face, char, flags)
        @face.glyph_slot
      end

      def load_glyph(index, *flags)
        flags = [:DEFAULT] if flags.size == 0
        flags = flags.map { |f| LoadFlag[f] }.reduce(&:|)
        FT.Load_Glyph(@face, index, flags)
        @face.glyph_slot
      end

      def render_glyph(*flags)
        flags = [:NORMAL] if flags.size == 0
        flags = flags.reduce { |a, flag| a | RenderMode[flag] }
        FT.Render_Glyph(@face.glyph_slot, flags)
        @face.glyph_slot
      end

      def has_kerning?
        (@face.face_flags & FT::FaceFlag[:KERNING]) != 0
      end

      # def height
      #   @face.ascender / 64.0
      # end

      def set_char_size(height: , width: 0, hdpi: 96, vdpi: 96)
        FT.Set_Char_Size(@face, (width * 64).to_i, (height * 64).to_i, hdpi, vdpi)
      end

      def height
        @height ||= begin
          sizes = each_char.map do |_, index|
            load_glyph(index, :NO_BITMAP)
            m = glyph_slot.metrics
            [m.horiBearingY, m.horiBearingY - m.height] #ymax, ymin
          end.transpose

          ymax, ymin = sizes.first.max, sizes.last.min
          (ymax - ymin) / 64
        end
      end

      def max_width
        charmap = {}
        @height ||= begin
          each_char.map do |_, index|
            if charmap.has_key?(index)
              next 0
            end
            load_glyph(index)
            render_glyph
            charmap[index] = glyph_slot.bitmap.width
          end.reduce(0, :+)
        end
      end

      # Glyph Variants
      # http://www.freetype.org/freetype2/docs/reference/ft2-glyph_variants.html
      def chars_of_variant(variant_selector)
        FT.Face_GetCharsOfVariant(@face, variant_selector)
      end

      def char_variant_index(charcode, variant_selector)
        FT.Face_GetCharVariantIndex(@face, charcode, variant_selector)
      end

      def char_variant_is_default(charcode, variant_selector)
        FT.Face_GetCharVariantIsDefault(@face, charcode, variant_selector)
      end

      def variant_selectors
        FT.Face_GetVariantSelectors(@face)
      end

      def variants_of_char(charcode)
        FT.Face_GetVariantsOfChar(@face, charcode)
      end

      def set_pixel_size(height, width = 0)
        FT.Set_Pixel_Sizes(@face, width, height)
      end
    end
  end
end
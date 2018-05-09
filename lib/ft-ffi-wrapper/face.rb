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
              LOGGER.debug "releasing FT_Face #{face.to_ptr}"
              FT.Done_Face(face)
              LOGGER.debug "released FT_Face #{face_ptr}."
              finalizer[:face] = nil
            end
          end
        end
      end

      def self.to_code(char)
        char.is_a?(Integer) ? char : char.unpack('U').first
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

      def kerning(left_glyph, right_glyph, mode = :DEFAULT)
        v = FT::Vector.new
        FT.Get_Kerning(@face, left_glyph, right_glyph, FT::KerningMode[mode], v)
        [v.x / 64.0, v.y / 64.0]
      end

      def glyph_slot
        @face.glyph_slot
      end

      def render_glyph(*flags)
        flags = [:NORMAL] if flags.size == 0
        flags = flags.reduce { |a, flag| a | RenderMode[flag] }
        FT.Render_Glyph(@face.glyph_slot, flags)
      end

      def has_kerning?
        (@face.face_flags & FT::FaceFlag[:KERNING]) != 0
      end

      def height
        @face.ascender / 64.0
      end

      def load_char(char, *flags)
        char = self.class.to_code(char)
        return unless char
        flags = [:DEFAULT] if flags.size == 0
        flags = flags.reduce { |a, flag| a | LoadFlag[flag] }
        FT.Load_Char(@face, char, flags)
      end

      def load_glyph(index, *flags)
        flags = [:DEFAULT] if flags.size == 0
        flags = flags.map { |f| LoadFlag[f] }.reduce(&:|)
        FT.Load_Glyph(@face, index, flags)
      end

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

      class Rect
        attr_accessor :left, :top, :right, :bottom
        def initialize(left, top, right, bottom)
          @left, @top, @right, @bottom = left, top, right, bottom
        end

        def height
          @bottom - @top + 1
        end

        def width
          @right - @left + 1
        end

        def area
          width * height
        end
      end

      class GlyphData
        attr_accessor :charcode, :width, :height, :advance, :index, :data
        def initialize(charcode, width, height, advance, index, data)
          @charcode = charcode
          @width    = width
          @height   = height
          @advance  = advance
          @index    = index
          @data     = data
        end

        def size
          @data.size
        end

        # def to_s
        #   'w=%2i h=%2i dh=%2i size=%4i -> %4i  buf=%4i' % [
        #       @width, @height, size - @height, size, width * self.height, data.size
        #   ]
        # end
      end

      class Node
        attr_accessor :left, :right, :rect, :index, :map

        def initialize
          @map = {}
        end

        def [](i)
          @map[i]
        end

        def[]=(i, glyph)
          @map[i] = glyph
        end

        def insert(glyph)
          return @left.insert(glyph) || @right.insert(glyph) unless leaf?
          return if @index
          return self if glyph.width == @rect.width && glyph.height == @rect.height # fits perfectly
          return if glyph.width > @rect.width || glyph.height > @rect.height # doesn't fit
          # split this node
          @left  = Node.new
          @right = Node.new
          dw = rect.width  - glyph.width
          dh = rect.height - glyph.height
          if dw > dh
            @left.rect  = Rect.new(rect.left, rect.top, rect.left + glyph.width - 1, rect.bottom)
            @right.rect = Rect.new(rect.left + glyph.width, rect.top, rect.right, rect.bottom)
          else
            @left.rect  = Rect.new(rect.left, rect.top, rect.right, rect.top + glyph.height - 1)
            @right.rect = Rect.new(rect.left, rect.top + glyph.height, rect.right, rect.bottom)
          end
          @left.insert(glyph)
        end

        def visit(&block)
          return unless block_given?
          @left&.visit(&block)
          yield self if @index
          @right&.visit(&block)
        end

        def leaf?
          !(@left && @right)
        end

        def to_s
          leaf? ? "#{index&.charcode}" : "node\n\tleft=#{@left}\n\tright=#{@right}"
        end
      end

      def dump(height:)
        set_char_size(height: height)
        self.height # force initialize height

        charmap = {}
        total_area = 0
        each_char do |charcode, index|
          next if charmap.has_key?(index)

          load_glyph(index)
          render_glyph

          width = glyph_slot.bitmap.width
          height = glyph_slot.bitmap.rows
          advance = glyph_slot.advance
          size = width * height

          next if width == 0
          total_area += size

          buffer = glyph_slot.bitmap.buffer.read_array_of_uchar(size)
          glyph = GlyphData.new(charcode, width, height, advance, index, buffer)
          charmap[index] = glyph
        end

        side = (Math.sqrt(total_area) * 1.03).ceil

        side = 2 ** (Math.log(side) / Math.log(2)).ceil - 1

        root = Node.new
        root.rect = Rect.new(0, 0, side, side)

        charmap.values.sort_by { |buffer| -buffer.size }.each do |glyph|
          node = root.insert(glyph)
          LOGGER.warn "doesn't fit" if node.nil?
          node.index = glyph
        end
        root
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
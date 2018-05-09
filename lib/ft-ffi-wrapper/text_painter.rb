module FT
  module Wrapper
    class TextPainter
      def initialize(context, left, top, font)
        @context, @left, @top, @font = context, left, top, font
        @face, @atlas = font.send(:face), font.send(:atlas, context)
        @buffer = []
      end

      def paint(char, background, foreground)
        glyph = @atlas.get_glyph(char)
        @buffer << [glyph, background, foreground, width(glyph, @buffer.empty? ? nil : @buffer.last.first)]
        nil
      end

      def finished
        @buffer.each do |glyph, background, foreground, width|

        end

        nil
      end

      private
      def width(glyph, prev)
        width = glyph.advance.x

        if prev
          kx, _ = @font.kerning(prev.index, glyph.index)
          width += kx
        end

        width
      end
    end
  end
end
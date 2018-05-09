module FT
  module Wrapper
    class Glyph
      attr_reader :charcode, :index

      def initialize(atlas, charcode, index,
                     atlas_x,              # pixel position in atlas
                     width, height,        # size of glyph
                     bearing_x, bearing_y, # bearing
                     advance_x, advance_y) # advance

        @atlas, @charcode, @index, = atlas, charcode, index
        @atlas_rect = Rect.new(atlas_x, 0, width, height)
        @bearing = GLMath::Vector2[bearing_x, bearing_y]
        @advance = GLMath::Vector2[advance_x, advance_y]
      end

      def advance
        @advance.dup
      end

      def atlas_rect
        @atlas_rect.dup
      end

      def bearing
        @bearing.dup
      end

      def char
        [charcode].pack('U')
      end

      def coordinates(x0, y0)
        x0, y0 = x0 + @bearing.x, y0
        x1, y1 = x0 + @atlas_rect.width, y0 + @atlas_rect.height

        txr = texture_coords
        tx0, ty0, tx1, ty1 = txr.x, txr.y, txr.right, txr.bottom

        [
            [x0, y0, tx0, ty0],
            [x1, y0, tx1, ty0],
            [x0, y1, tx0, ty1],
            [x1, y1, tx1, ty1]
        ]
      end

      def texture_coords
        w, r = @atlas.width.to_f, @atlas_rect
        Rect.new(r.x / w, 0.0, r.width / w, 1.0)
      end

      def render

      end
    end
  end
end
#require 'chunky_png'
module FTWrapper
  class FontAtlas
    attr_reader :texture, :face, :width, :height, :allocated

    def initialize(face, height, baseline)
      @face, @width, @height, @baseline, @allocated, @glyphs = face, 512, height, baseline, 1, {}

      render_handle = Roglew::RenderHandle.current

      @texture = render_handle.bind do |context|
        context.create_texture2d
      end
      @texture.bind do |tc|
        tc.no_mipmaps!

        render_handle.glPixelStorei(Roglew::GL::UNPACK_ALIGNMENT, 1)
        tc.tex_image_2d(@width, @height, Roglew::GL::R8, Roglew::GL::RED, Roglew::GL::FLOAT)
      end

      @program = FontAtlasProgram.new(render_handle)
    end

    def handle
      @texture.handle
    end

    def get_glyph(char, tc = nil)
      has_tc = tc

      char = FT::Face.to_code(char)
      glyph = @glyphs[char]
      unless glyph
        tc = @texture.bind unless has_tc
        glyph, tc = alloc_glyph(char, tc)
        tc.finished unless has_tc
        @glyphs[char] = glyph
      end

      has_tc ? [glyph, tc] : glyph
    end

    def paint(font, text, mvp)
      get_glyphs(text) do |glyphs|
        return if glyphs.empty?
        pointer = FFI::MemoryPointer.new(FontAtlasProgram::Quad, text.length, false)
        ax, ay, prev_idx = 0, 0, nil
        glyphs.each_with_index do |glyph, i|
          quad = FontAtlasProgram::Quad.new(pointer[i]).vertices

          if prev_idx
            kx, ky = font.kerning(prev_idx, glyph.index)
            ax, ay = ax + kx, ay + ky
          end
          prev_idx = glyph.index

          glyph.coordinates(ax, ay).each_with_index do |c, j|
            v = quad[j]
            v.x, v.y, v.tx, v.ty = c
          end

          advance = glyph.advance
          ax, ay = ax + advance.x, ay + advance.y
        end

        handle.bind do |context|
          context.enable(Roglew::GL::BLEND) do
            @program.use do
              @program.fontTexId 0
              @program.mvp 1, true, mvp.native
              @program.buffer_data pointer, Roglew::GL::STREAM_DRAW
              @program.paint(text.length)
            end
          end
        end

        #dump_atlas
      end
    end

    private

    def alloc_glyph(charcode, tc)
      index = @face.char_index(charcode)
      @face.load_glyph(index, :RENDER)

      gs = @face.glyph_slot
      bitmap = gs.bitmap
      ax, ay = gs.advance.x / 64, gs.advance.y / 64
      gx, gw, gh, gl, gt = @allocated, bitmap.width, bitmap.rows, gs.bitmap_left, gs.bitmap_top

      if gx + gw > @width
        tc.finished
        tc = expand_texture
      end

      tc.handle.glPixelStorei(Roglew::GL::UNPACK_ALIGNMENT, 1)
      tc.tex_subimage_2d(gx, @baseline - gt, gw, gh, Roglew::GL::RED, Roglew::GL::UNSIGNED_BYTE, bitmap.atlas)

      #dump_atlas

      #if gw*gh > 0
      #
      #  buffer = bitmap.atlas.read_array_of_uint8(gw*gh).each_slice(gw).to_a
      #
      #  image = ChunkyPNG::Image.new(gw, gh)
      #
      #  gh.times do |y|
      #    gw.times do |x|
      #      image[x, y] = ChunkyPNG::Color.rgb(*([255 - buffer[y][x]] * 3))
      #    end
      #  end
      #
      #  image.save("E:\\Users\\Silver Phoenix\\Temp\\font_cache\\font_cache_#{index}.png")
      #
      #end

      @allocated += gw
      [Glyph.new(self, charcode, index, gx, gw, height, gl, @baseline, ax, ay), tc]
    end

    def bind
      @texture.bind { |tc| yield tc }
    end

    def expand_texture
      handle.bind do |context|
        old_texture, @texture = @texture, context.create_texture2d
        @width += 512 #new width

        @texture.bind do |tc|
          tc.no_mipmaps!
          tc.tex_image_2d(@width, @height, Roglew::GL::R8, Roglew::GL::RED, Roglew::GL::FLOAT)
        end

        context.create_framebuffer.bind(Roglew::GL::READ_FRAMEBUFFER) do |fc1|
          fc1.attach(old_texture, Roglew::GL::COLOR_ATTACHMENT0)

          context.create_framebuffer.bind(Roglew::GL::DRAW_FRAMEBUFFER) do |fc2|
            fc2.attach(@texture, Roglew::GL::COLOR_ATTACHMENT0)

            #copy allocated image part to new image
            handle.glBlitFramebuffer(
              0, 0, @allocated, @height, #src
              0, 0, @allocated, @height, #dst
              Roglew::GL::COLOR_BUFFER_BIT, Roglew::GL::NEAREST)
          end
        end
      end

      @texture.bind
    end

    def get_glyphs(text)
      glyphs, tc = [], @texture.bind

      text.each_char do |char|
        glyph, tc = get_glyph(char, tc)
        glyphs << glyph
      end

      if block_given?
        yield glyphs
        tc.finished
      else
        [glyphs, tc]
      end
    end

    #def dump_atlas
    #  pixels = FFI::MemoryPointer.new(:uint8, width*height)
    #  handle.glPixelStorei(Roglew::GL::PACK_ALIGNMENT, 1)
    #  handle.glGetTexImage(Roglew::GL::TEXTURE_2D, 0, Roglew::GL::RED, Roglew::GL::UNSIGNED_BYTE, pixels)
    #  buffer = pixels.read_array_of_uint8(width*height).each_slice(width).to_a
    #
    #  image = ChunkyPNG::Image.new(width, height)
    #
    #  height.times do |y|
    #    width.times do |x|
    #      c = 255 - buffer[y][x]
    #      image[x, y] = ChunkyPNG::Color.rgba(c, c, c, 255)
    #    end
    #  end
    #
    #  image.save('E:\Users\Silver Phoenix\Temp\font_cache\atlas.png')
    #end
  end
end
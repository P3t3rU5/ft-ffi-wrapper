require 'chunky_png'
require_relative 'test_helper'
require 'ft-ffi-wrapper/library'
include FT::Wrapper

lib = Library.new
face = Face.new(lib, 'C:\Windows\Fonts\arial.ttf')

root = face.dump(height: 72)
image = ChunkyPNG::Image.new(root.rect.height, root.rect.width, ChunkyPNG::Color::TRANSPARENT)
root.visit do |node|
  glyph = node.index
  root[glyph.charcode] = node
  sub_image = ChunkyPNG::Image.new(glyph.width, glyph.height, glyph.data)
  image.compose!(sub_image, node.rect.left, node.rect.top)
  image.metadata[glyph.charcode.to_s] = "[#{node.rect.left}, #{node.rect.top}, #{node.rect.width}, #{node.rect.height}]"
end

# signed distance field
# sdf parameters(map, w, h, x, y, max_radius)
# root.visit do |node|
#   glyph = node.index
#   max_radius = 72 * 2
#   d2 = max_radius ** 2 + 1.0
#   glyph.data.each_with_index do |v, i|
#     x = i % glyph.width
#     y = i / glyph.width
#     puts "point(#{x}, #{y})"
#     1.upto(max_radius) do |r|
#       break if r ** 2 < 2
#
#       # north
#       line = y - r
#       if (0...glyph.height).include?(line)
#         lo = x - r
#         hi = x + r
#         lo = 0 if lo < 0
#         hi = glyph.width - 1 if hi >= glyph.width
#         idx = line * glyph.width + lo
#         lo.upto(hi) do |j|
#           if glyph.data[idx] != v
#             nx  = j - x
#             ny  = line - y
#             nd2 = nx ** 2 + ny ** 2
#             d2  = nd2 if nd2 < d2
#           end
#           idx += 1
#         end
#       end
#
#       # south
#       line = y + r
#       if (0...glyph.height).include?(line)
#         lo = x - r
#         hi = x + r
#         lo = 0 if lo < 0
#         hi = glyph.width - 1 if hi >= glyph.width
#         idx = line * glyph.width + lo
#         lo.upto(hi) do |j|
#           if glyph.data[idx] != v
#             nx = j - x
#             ny = line - y
#             nd2 = nx ** 2 + ny ** 2
#             d2 = nd2 if nd2 < d2
#           end
#           idx += 1
#         end
#       end
#
#       # west
#       line = x - r
#       if (0...glyph.height).include?(line)
#         lo = y - r + 1
#         hi = y + r - 1
#         lo = 0 if lo < 0
#         hi = glyph.height - 1 if hi >= glyph.height
#         idx = lo * glyph.width + line
#         lo.upto(hi) do |j|
#           if glyph.data[idx] != v
#             nx = line - x
#             ny = j - y
#             nd2 = nx * nx + ny * ny
#             d2 = nd2 if nd2 < d2
#           end
#           idx += glyph.width
#         end
#       end
#
#       # east
#       line = x + r
#       if (0...glyph.height).include?(line)
#         lo = y - r + 1
#         hi = y + r - 1
#         lo = 0 if lo < 0
#         hi = glyph.height - 1 if hi >= glyph.height
#         idx = lo * glyph.width + line
#         lo.upto(hi).each do |j|
#           if glyph.data[idx] != v
#             nx = line - x
#             ny = j - y
#             nd2 = nx ** 2 + ny ** 2
#             d2 = nd2 if nd2 < d2
#           end
#           idx += glyph.width
#         end
#       end
#
#     end
#     d2 = Math.sqrt(d2)
#     d2 = -d2 if v == 0
#     d2 *= 127.5 / max_radius
#     d2 += 127.5
#     d2 = 0 if d2 < 0
#     d2 = 255 if d2 > 255
#     d2 += 0.5
#     glyph.data[i] = d2.floor
#   end
#   sub_image = ChunkyPNG::Image.new(node.index.width, node.index.height, node.index.data)
#   image.compose!(sub_image, node.rect.left, node.rect.top)
# end

image.save('atlas_test.png')


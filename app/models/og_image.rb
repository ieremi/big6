class OgImage
  WIDTH = 1200
  HEIGHT = 630

  private

  def hex_to_rgb(hex)
    hex = hex.delete("#")
    [ hex[0, 2].to_i(16), hex[2, 2].to_i(16), hex[4, 2].to_i(16) ]
  end

  def dpi_to_fit(text, target_width, base_dpi: 100, max_dpi: nil)
    sample = Vips::Image.text(text, dpi: base_dpi)
    dpi = (base_dpi * target_width / sample.width.to_f).round
    max_dpi ? [ dpi, max_dpi ].min : dpi
  end

  def overlay_text(bg, text, dpi:, center_y:)
    rendered = Vips::Image.text(text, align: :centre, dpi: dpi)
    colored = rendered.new_from_image([ 255, 255, 255 ]).bandjoin(rendered).copy(interpretation: :srgb)
    x = (bg.width - colored.width) / 2
    y = center_y - colored.height / 2
    [ bg.composite2(colored, :over, x: x, y: y), colored.height ]
  end

  def diagonal_split(left_hex, right_hex, slope: -0.6)
    xyz = Vips::Image.xyz(WIDTH, HEIGHT)
    x = xyz[0]
    y = xyz[1]
    line_x = (y - HEIGHT / 2.0) * slope + (WIDTH / 2.0)
    mask = x < line_x

    mask.ifthenelse(hex_to_rgb(left_hex), hex_to_rgb(right_hex)).cast(:uchar).copy(interpretation: :srgb)
  end

  def solid_background(hex)
    (Vips::Image.black(WIDTH, HEIGHT) + hex_to_rgb(hex)).cast(:uchar).copy(interpretation: :srgb)
  end

  def stripe_background(hexes)
    band_width = (WIDTH.to_f / hexes.size).ceil
    bands = hexes.map { |hex| (Vips::Image.black(band_width, HEIGHT) + hex_to_rgb(hex)).cast(:uchar) }
    bands.reduce { |acc, band| acc.join(band, :horizontal) }.crop(0, 0, WIDTH, HEIGHT).copy(interpretation: :srgb)
  end

  def contrast_band(bg, center_y:, height:, opacity: 140)
    color_band = (Vips::Image.black(bg.width, height) + [ 17, 24, 39 ]).cast(:uchar)
    alpha_band = (Vips::Image.black(bg.width, height) + opacity).cast(:uchar)
    band = color_band.bandjoin(alpha_band).copy(interpretation: :srgb)
    bg.composite2(band, :over, x: 0, y: center_y - height / 2)
  end

  def finalize(bg)
    bg = bg.flatten(background: [ 30, 30, 30 ]) if bg.bands == 4
    bg.write_to_buffer(".png")
  end
end

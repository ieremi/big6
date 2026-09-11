class GameOgImage
  WIDTH = 1200
  HEIGHT = 630
  SLOPE = -0.6
  MAIN_TEXT_TARGET_WIDTH = 1050

  def initialize(game)
    @game = game
  end

  def to_png
    team0 = @game.team0
    team1 = @game.team1

    bg = diagonal_split(team0.color, team1.color)

    main_text = "#{team0.initial} #{@game.team0_score} - #{@game.team1_score} #{team1.initial}"
    main_dpi = dpi_to_fit(main_text, MAIN_TEXT_TARGET_WIDTH)
    bg, = overlay_text(bg, main_text, dpi: main_dpi, center_y: 260)

    bg, = overlay_text(bg, "#{@game.season.year} #{@game.season.term.capitalize} - Round #{@game.game_number}", dpi: 115, center_y: 460)
    bg, = overlay_text(bg, @game.played_on.to_s, dpi: 100, center_y: 505)
    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: 90, center_y: 545)

    bg = bg.flatten(background: [ 30, 30, 30 ]) if bg.bands == 4
    bg.write_to_buffer(".png")
  end

  private

  def diagonal_split(left_hex, right_hex)
    xyz = Vips::Image.xyz(WIDTH, HEIGHT)
    x = xyz[0]
    y = xyz[1]
    line_x = (y - HEIGHT / 2.0) * SLOPE + (WIDTH / 2.0)
    mask = x < line_x

    mask.ifthenelse(hex_to_rgb(left_hex), hex_to_rgb(right_hex)).cast(:uchar).copy(interpretation: :srgb)
  end

  def hex_to_rgb(hex)
    hex = hex.delete("#")
    [ hex[0, 2].to_i(16), hex[2, 2].to_i(16), hex[4, 2].to_i(16) ]
  end

  def dpi_to_fit(text, target_width, base_dpi: 100)
    sample = Vips::Image.text(text, dpi: base_dpi)
    (base_dpi * target_width / sample.width.to_f).round
  end

  def overlay_text(bg, text, dpi:, center_y:)
    rendered = Vips::Image.text(text, align: :centre, dpi: dpi)
    colored = rendered.new_from_image([ 255, 255, 255 ]).bandjoin(rendered).copy(interpretation: :srgb)
    x = (bg.width - colored.width) / 2
    y = center_y - colored.height / 2
    [ bg.composite2(colored, :over, x: x, y: y), colored.height ]
  end
end

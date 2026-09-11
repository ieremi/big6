class GameOgImage
  WIDTH = 1200
  HEIGHT = 630

  def initialize(game)
    @game = game
  end

  def to_png
    team0 = @game.team0
    team1 = @game.team1

    left = solid_rect(WIDTH / 2, HEIGHT, team0.color)
    right = solid_rect(WIDTH - WIDTH / 2, HEIGHT, team1.color)
    bg = left.join(right, :horizontal).copy(interpretation: :srgb)

    main_text = "#{team0.initial} #{@game.team0_score} - #{@game.team1_score} #{team1.initial}"
    bg = overlay_text(bg, main_text, dpi: 300, y_offset: -40)

    subtitle = "#{@game.season.year} #{@game.season.term.capitalize} · Round #{@game.game_number} · #{@game.played_on}"
    bg = overlay_text(bg, subtitle, dpi: 130, y_offset: 90)

    bg.write_to_buffer(".png")
  end

  private

  def solid_rect(w, h, hex)
    (Vips::Image.black(w, h) + hex_to_rgb(hex)).cast(:uchar)
  end

  def hex_to_rgb(hex)
    hex = hex.delete("#")
    [ hex[0, 2].to_i(16), hex[2, 2].to_i(16), hex[4, 2].to_i(16) ]
  end

  def overlay_text(bg, text, dpi:, y_offset:)
    rendered = Vips::Image.text(text, width: WIDTH - 100, align: :centre, dpi: dpi)
    colored = rendered.new_from_image([ 255, 255, 255 ]).bandjoin(rendered).copy(interpretation: :srgb)
    x = (bg.width - colored.width) / 2
    y = (bg.height - colored.height) / 2 + y_offset
    bg.composite2(colored, :over, x: x, y: y)
  end
end

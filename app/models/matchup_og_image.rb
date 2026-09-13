class MatchupOgImage < OgImage
  NUMBER_TARGET_WIDTH = 300
  INITIAL_RATIO = 0.7
  BOTTOM_MARGIN = 50
  GAP_SMALL = 14

  def initialize(team0, team1, wins0:, wins1:, subtitle:)
    @team0 = team0
    @team1 = team1
    @wins0 = wins0
    @wins1 = wins1
    @subtitle = subtitle
  end

  def to_png
    bg = diagonal_split(@team0.color, @team1.color)

    longer = [ @wins0.to_s, @wins1.to_s ].max_by(&:length)
    number_dpi = dpi_to_fit(longer, NUMBER_TARGET_WIDTH, max_dpi: 1000)
    initial_dpi = (number_dpi * INITIAL_RATIO).round
    text_dpi = (number_dpi * 0.5).round

    subtitle_h = text_height(@subtitle, text_dpi)
    credit_h = text_height("Tokyo Big 6 Baseball", text_dpi)

    credit_center_y = HEIGHT - BOTTOM_MARGIN - credit_h / 2.0
    subtitle_center_y = credit_center_y - credit_h / 2.0 - GAP_SMALL - subtitle_h / 2.0

    number_center_y = HEIGHT / 2.0

    left_x = WIDTH * 0.27
    right_x = WIDTH * 0.73

    bg = corner_initials(bg, @team0, @team1, dpi: initial_dpi)

    bg, = overlay_text(bg, @wins0.to_s, dpi: number_dpi, center_x: left_x, center_y: number_center_y)
    bg, = overlay_text(bg, "-", dpi: number_dpi, center_x: WIDTH / 2.0, center_y: number_center_y)
    bg, = overlay_text(bg, @wins1.to_s, dpi: number_dpi, center_x: right_x, center_y: number_center_y)

    bg, = overlay_text(bg, @subtitle, dpi: text_dpi, center_y: subtitle_center_y)
    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: text_dpi, center_y: credit_center_y)

    finalize(bg)
  end
end

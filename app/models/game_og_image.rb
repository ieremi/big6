class GameOgImage < OgImage
  NUMBER_TARGET_WIDTH = 300
  INITIAL_RATIO = 0.7
  BOTTOM_MARGIN = 50
  GAP_SMALL = 14

  def initialize(game)
    @game = game
  end

  def to_png
    team0 = @game.team0
    team1 = @game.team1

    bg = diagonal_split(team0.color, team1.color)

    in_progress = @game.team0_score.nil? || @game.team1_score.nil?
    left_value = @game.team0_score.to_s
    right_value = @game.team1_score.to_s

    number_dpi = if in_progress
      dpi_to_fit("vs", NUMBER_TARGET_WIDTH, max_dpi: 1000)
    else
      longer = [ left_value, right_value ].max_by(&:length)
      dpi_to_fit(longer, NUMBER_TARGET_WIDTH, max_dpi: 1000)
    end
    initial_dpi = (number_dpi * INITIAL_RATIO).round
    text_dpi = (number_dpi * 0.5).round

    round_line = "#{@game.season.year} #{@game.season.term.capitalize} - Round #{@game.game_number}"
    date_line = @game.played_on.to_s
    credit_line = "Tokyo Big 6 Baseball"

    initial_h = text_height(team0.initial, initial_dpi)
    number_h = text_height(in_progress ? "vs" : left_value, number_dpi)
    round_h = text_height(round_line, text_dpi)
    date_h = text_height(date_line, text_dpi)
    credit_h = text_height(credit_line, text_dpi)

    credit_center_y = HEIGHT - BOTTOM_MARGIN - credit_h / 2.0
    date_center_y = credit_center_y - credit_h / 2.0 - GAP_SMALL - date_h / 2.0
    round_center_y = date_center_y - date_h / 2.0 - GAP_SMALL - round_h / 2.0

    top_block_bottom = CORNER_MARGIN + initial_h + GAP_SMALL * 2
    bottom_block_top = round_center_y - round_h / 2.0 - GAP_SMALL * 2
    number_center_y = (top_block_bottom + bottom_block_top) / 2.0

    left_x = WIDTH * 0.27
    right_x = WIDTH * 0.73

    bg = corner_initials(bg, team0, team1, dpi: initial_dpi)

    if in_progress
      bg, = overlay_text(bg, "vs", dpi: number_dpi, center_y: number_center_y)
    else
      bg, = overlay_text(bg, left_value, dpi: number_dpi, center_x: left_x, center_y: number_center_y)
      bg, = overlay_text(bg, "-", dpi: number_dpi, center_x: WIDTH / 2.0, center_y: number_center_y)
      bg, = overlay_text(bg, right_value, dpi: number_dpi, center_x: right_x, center_y: number_center_y)
    end

    bg, = overlay_text(bg, round_line, dpi: text_dpi, center_y: round_center_y)
    bg, = overlay_text(bg, date_line, dpi: text_dpi, center_y: date_center_y)
    bg, = overlay_text(bg, credit_line, dpi: text_dpi, center_y: credit_center_y)

    finalize(bg)
  end
end

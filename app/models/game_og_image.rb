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
    scoreboard = live_scoreboard if in_progress
    progress_line = scoreboard && progress_label(scoreboard)
    show_score = !in_progress || progress_line.present?

    left_value = (in_progress ? scoreboard&.top_total : @game.team0_score).to_s
    right_value = (in_progress ? scoreboard&.bottom_total : @game.team1_score).to_s

    number_dpi = if show_score
      longer = [ left_value, right_value ].max_by(&:length)
      dpi_to_fit(longer, NUMBER_TARGET_WIDTH, max_dpi: 1000)
    else
      dpi_to_fit("vs", NUMBER_TARGET_WIDTH, max_dpi: 1000)
    end
    initial_dpi = (number_dpi * INITIAL_RATIO).round
    text_dpi = (number_dpi * 0.5).round

    round_line = "#{@game.season.year} #{@game.season.term.capitalize} - Round #{@game.game_number}"
    date_line = @game.played_on.to_s
    credit_line = "Tokyo Big 6 Baseball"
    bottom_lines = [ round_line, date_line, credit_line ]
    bottom_lines.unshift(progress_line) if show_score && in_progress

    initial_h = text_height(team0.initial, initial_dpi)
    number_h = text_height(show_score ? left_value : "vs", number_dpi)
    line_heights = bottom_lines.map { |line| text_height(line, text_dpi) }

    line_center_ys = Array.new(bottom_lines.size)
    cursor = HEIGHT - BOTTOM_MARGIN
    (bottom_lines.size - 1).downto(0) do |i|
      line_center_ys[i] = cursor - line_heights[i] / 2.0
      cursor -= line_heights[i] + GAP_SMALL
    end

    top_block_bottom = CORNER_MARGIN + initial_h + GAP_SMALL * 2
    bottom_block_top = line_center_ys.first - line_heights.first / 2.0 - GAP_SMALL * 2
    number_center_y = (top_block_bottom + bottom_block_top) / 2.0

    left_x = WIDTH * 0.27
    right_x = WIDTH * 0.73

    bg = corner_initials(bg, team0, team1, dpi: initial_dpi)

    if show_score
      bg, = overlay_text(bg, left_value, dpi: number_dpi, center_x: left_x, center_y: number_center_y)
      bg, = overlay_text(bg, "-", dpi: number_dpi, center_x: WIDTH / 2.0, center_y: number_center_y)
      bg, = overlay_text(bg, right_value, dpi: number_dpi, center_x: right_x, center_y: number_center_y)
    else
      bg, = overlay_text(bg, "vs", dpi: number_dpi, center_y: number_center_y)
    end

    bottom_lines.each_with_index do |line, i|
      bg, = overlay_text(bg, line, dpi: text_dpi, center_y: line_center_ys[i])
    end

    finalize(bg)
  end

  private

  # The box score's per-inning cells only fill in once that half-inning is
  # over, so the last one with data marks the last half known to be
  # complete — not a guess at whichever half is on now, which we can't see.
  def live_scoreboard
    scorebook = GameScoreboard.new(@game)
    return scorebook if scorebook.innings.any?

    official = LeagueOfficialScoreboard.new(@game)
    official.innings.any? ? official : nil
  end

  def progress_label(scoreboard)
    last = nil
    (1..18).each do |n|
      last = [ n, :top ] if scoreboard.top_runs(n).present?
      last = [ n, :bottom ] if scoreboard.bottom_runs(n).present?
    end
    return nil unless last

    n, half = last
    "#{n}回#{half == :top ? "表" : "裏"}終了"
  end
end

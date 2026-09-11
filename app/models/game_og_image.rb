class GameOgImage < OgImage
  MAIN_TEXT_TARGET_WIDTH = 1050

  def initialize(game)
    @game = game
  end

  def to_png
    team0 = @game.team0
    team1 = @game.team1

    bg = diagonal_split(team0.color, team1.color)

    main_text = "#{team0.initial} #{@game.team0_score} - #{@game.team1_score} #{team1.initial}"
    bg, = overlay_text(bg, main_text, dpi: dpi_to_fit(main_text, MAIN_TEXT_TARGET_WIDTH), center_y: 260)

    bg, = overlay_text(bg, "#{@game.season.year} #{@game.season.term.capitalize} - Round #{@game.game_number}", dpi: 115, center_y: 460)
    bg, = overlay_text(bg, @game.played_on.to_s, dpi: 100, center_y: 505)
    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: 90, center_y: 545)

    finalize(bg)
  end
end

class MatchupOgImage < OgImage
  MAIN_TEXT_TARGET_WIDTH = 1050

  def initialize(team0, team1, games, subtitle:)
    @team0 = team0
    @team1 = team1
    @games = games
    @subtitle = subtitle
  end

  def to_png
    bg = diagonal_split(@team0.color, @team1.color)

    wins0 = @games.count { |g| winner(g) == @team0 }
    wins1 = @games.count { |g| winner(g) == @team1 }
    main_text = "#{@team0.initial} #{wins0} - #{wins1} #{@team1.initial}"
    bg, = overlay_text(bg, main_text, dpi: dpi_to_fit(main_text, MAIN_TEXT_TARGET_WIDTH), center_y: 260)

    bg, = overlay_text(bg, @subtitle, dpi: 115, center_y: 460)
    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: 90, center_y: 505)

    finalize(bg)
  end

  private

  def winner(game)
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0 : game.team1
  end
end

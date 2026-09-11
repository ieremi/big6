module GamesHelper
  def game_path(game)
    game_browse_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number)
  end
end

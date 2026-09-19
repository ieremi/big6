module PlayersHelper
  ROLE_GROUP_LABELS = {
    "player" => "選手",
    "manager" => "マネージャー",
    "staff" => "監督・コーチ・部長",
    "other" => "その他（学生コーチ・アナリストなど）"
  }.freeze

  # "右投左打" style; whichever half is known when only one is.
  def hands_label(player)
    [ ("#{player.pitching_hand}投" if player.pitching_hand), ("#{player.batting_hand}打" if player.batting_hand) ].compact.join
  end

  def enrollment_label(status)
    case status
    when Player::ACTIVE_ENROLLMENT_STATUS then "現役"
    when Player::ALUMNI_ENROLLMENT_STATUS then "卒業生"
    end
  end

  def players_page_path(page)
    players_path(request.query_parameters.merge("page" => page))
  end

  # The player's game page, from the point of view of the game they were on the roster for.
  def player_game_path(game)
    matchup_game_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number)
  end
end

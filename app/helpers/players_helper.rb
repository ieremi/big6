module PlayersHelper
  ROLE_GROUP_LABELS = {
    "player" => "選手",
    "manager" => "マネージャー",
    "staff" => "監督・コーチ・部長",
    "other" => "その他（学生コーチ・アナリストなど）"
  }.freeze

  def hands_label(player)
    player.hands_label
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

  # ".257" style, "1.000" for a perfect average, "---" when there was no at-bat.
  def batting_average_label(average)
    return "---" if average.nil?

    format("%.3f", average).sub(/\A0(?=\.)/, "")
  end

  # Innings pitched from outs: 10 outs is "3 1/3".
  def innings_label(outs)
    whole, thirds = outs.divmod(3)
    thirds.zero? ? whole.to_s : "#{whole} #{thirds}/3"
  end

  def era_label(era)
    era.nil? ? "---" : format("%.2f", era)
  end

  # The short name of the team the player's own team faced in this line's game.
  def opponent_name(line)
    game = line.game
    (game.team0_id == line.university_id ? game.team1 : game.team0).short_name
  end
end

module MatchupsHelper
  def streak_description(streak)
    return "記録なし" if streak.nil? || streak.length.zero?

    streak_link(streak)
  end

  def current_streak_description(streak)
    return "連勝中ではない" if streak.nil? || streak.length.zero?

    streak_link(streak)
  end

  private

  def streak_link(streak)
    first_label = "#{streak.first_game.season.title} 第#{streak.first_game.game_number}回戦"
    last_label = "#{streak.last_game.season.title} 第#{streak.last_game.game_number}回戦"

    if streak.first_game == streak.last_game
      safe_join([ "#{streak.length}連勝（", link_to(first_label, game_path(streak.first_game)), "）" ])
    else
      safe_join([ "#{streak.length}連勝（", link_to(first_label, game_path(streak.first_game)), " 〜 ", link_to(last_label, game_path(streak.last_game)), "）" ])
    end
  end
end

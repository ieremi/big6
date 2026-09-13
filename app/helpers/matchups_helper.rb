module MatchupsHelper
  def streak_description(streak)
    return "記録なし" if streak.nil? || streak.length.zero?

    streak_link(streak)
  end

  def current_streak_description(streak)
    return "連勝中ではない" if streak.nil? || streak.length.zero?

    streak_link(streak)
  end

  def duration_description(minutes)
    return "—" if minutes.nil?

    hours, mins = minutes.divmod(60)
    hours.positive? ? "#{hours}時間#{mins}分" : "#{mins}分"
  end

  private

  def streak_link(streak)
    first_label = streak_game_label(streak, streak.first_game)
    last_label = streak_game_label(streak, streak.last_game)

    if streak.first_game == streak.last_game
      safe_join([ "#{streak.length}連勝（", link_to(first_label, game_path(streak.first_game)), "）" ])
    else
      safe_join([ "#{streak.length}連勝（", link_to(first_label, game_path(streak.first_game)), " 〜 ", link_to(last_label, game_path(streak.last_game)), "）" ])
    end
  end

  def streak_game_label(streak, game)
    opponent = game.team0 == streak.team ? game.team1 : game.team0
    week_number = week_number_for(game)
    "#{game.season.title} 第#{week_number}週 vs #{opponent.short_name} 第#{game.game_number}回戦"
  end

  def week_number_for(game)
    weeks = SeasonWeeks.new(game.season.games.includes(:team0, :team1)).weeks
    weeks.find { |w| w.games.any? { |g| g.id == game.id } }&.number
  end
end

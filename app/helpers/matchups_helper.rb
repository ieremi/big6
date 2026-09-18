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
    weeks = weeks_for_season(game.season)
    weeks.find { |w| w.games.any? { |g| g.id == game.id } }&.number
  end

  # The matchup show page can ask for a week number for several streak
  # endpoints across several periods, often landing back in the same
  # season — memoized per season (within this one request/render) instead
  # of SeasonWeeks re-querying and regrouping that season's full game list
  # from scratch every time.
  def weeks_for_season(season)
    @weeks_by_season_id ||= {}
    @weeks_by_season_id[season.id] ||= SeasonWeeks.new(season.games.includes(:team0, :team1)).weeks
  end
end

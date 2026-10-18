class RankingsController < ApplicationController
  PER_PAGE = 50

  def index
    @kind = PlayerRanking::KINDS.include?(params[:kind]) ? params[:kind] : "batting"
    @seasons = PlayerRanking.seasons_with_stats(@kind).to_a
    @missing_seasons = PlayerRanking.seasons_without_stats(@kind)
    @complete_since = PlayerRanking.complete_since(@kind)
    # The period: one season (season=2026-spring), the whole career (season=, as
    # the 通算 choice sends it), or the stretch from which every season has
    # per-game stats (season=complete, complete_since), so that a player's totals
    # aren't short of seasons Scorebook has no box scores for; without any such
    # gap, that stretch is the whole career. With no season at all it is the
    # latest season with stats (the current one, as the league's own rankings
    # are).
    @season = params[:season].nil? ? @seasons.first : @seasons.find { |season| "#{season.year}-#{season.term}" == params[:season] }
    @since = @complete_since if @season.nil? && (params[:season].nil? || params[:season] == "complete")
    @period = @season ? :season : (@since ? :complete : :career)
    @universities = University.order(:position)
    @selected_university_ids = Array(params[:university_ids]).map(&:to_i) & @universities.map(&:id)
    @active_only = params[:active_only].present?

    # What the minimum is if not asked for (it depends on the period), and what it is.
    # The form always sends the minimum it shows, and the default it showed it beside
    # (default_minimum): a minimum still equal to that wasn't changed, so the default
    # of the period now chosen applies, not the one of the period it was left.
    # A season's default is the league's minimum (PlayerRanking::LEAGUE), as on the
    # league's rankings; it is only for a season, and any other period falls back to
    # its default number. number_minimum is the number shown when a season's
    # minimum is switched to a number (数で指定する).
    @number_minimum = PlayerRanking.default_minimum(@kind, season: @season)
    @default_minimum = @season ? PlayerRanking::LEAGUE : @number_minimum
    asked = PlayerRanking.minimum_from(params[:minimum])
    asked = nil if asked == PlayerRanking::LEAGUE && @season.nil?
    @minimum = (asked unless asked == PlayerRanking.minimum_from(params[:default_minimum])) || @default_minimum

    # Batters are ranked by batting average, as the league ranks them (the Web API
    # keeps OPS); pitchers by ERA either way.
    ranking = PlayerRanking.new(@kind, season: @season, since: @since, university_ids: @selected_university_ids.presence, minimum: @minimum,
      active_only: @active_only, order_by: "average")
    @league_minimums = ranking.league_minimums
    @stats_through = ranking.stats_through
    @sort_order = PlayerRanking.sort_order(@kind, params[:sort], params[:direction]) # empty for the ranking's own order
    sorted = ranking.entries_sorted(@sort_order)
    @ranked_count = sorted.size
    # The top 10 places at first (ties included); top= changes how many, and a
    # blank or "all" shows every one.
    @top = PlayerRanking.top_from(params[:top])
    entries = PlayerRanking.within_top(sorted, @top)
    @total_count = entries.size
    @last_page = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @last_page)
    @entries = entries.slice((@page - 1) * PER_PAGE, PER_PAGE) || []
  end
end

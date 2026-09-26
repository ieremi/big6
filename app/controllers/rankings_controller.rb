class RankingsController < ApplicationController
  PER_PAGE = 50

  def index
    @kind = PlayerRanking::KINDS.include?(params[:kind]) ? params[:kind] : "batting"
    @seasons = PlayerRanking.seasons_with_stats(@kind).to_a
    @missing_seasons = PlayerRanking.seasons_without_stats(@kind)
    @complete_since = PlayerRanking.complete_since(@kind)
    # The period: one season (season=2026-spring), the whole career (season=, as
    # the 通算 choice sends it), or, with no season at all, the stretch from
    # which every season has per-game stats (complete_since), so that a player's
    # totals aren't short of seasons Scorebook has no box scores for. Without
    # any such gap, that stretch is the whole career.
    @season = @seasons.find { |season| "#{season.year}-#{season.term}" == params[:season] }
    @since = @complete_since if @season.nil? && (params[:season].nil? || params[:season] == "complete")
    @period = @season ? :season : (@since ? :complete : :career)
    @universities = University.order(:position)
    @selected_university_ids = Array(params[:university_ids]).map(&:to_i) & @universities.map(&:id)
    @active_only = params[:active_only].present?

    # What the minimum is if not asked for (it depends on the period), and what it is.
    # The form always sends the minimum it shows, and the default it showed it beside
    # (default_minimum): a minimum still equal to that wasn't changed, so the default
    # of the period now chosen applies, not the one of the period it was left.
    @default_minimum = PlayerRanking.default_minimum(@kind, season: @season)
    asked = PlayerRanking.minimum_from(params[:minimum])
    @minimum = (asked unless asked == PlayerRanking.minimum_from(params[:default_minimum])) || @default_minimum

    ranking = PlayerRanking.new(@kind, season: @season, since: @since, university_ids: @selected_university_ids.presence, minimum: @minimum, active_only: @active_only)
    @sort = PlayerRanking.sort_keys(@kind).include?(params[:sort]) ? params[:sort] : "rank"
    @direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : PlayerRanking.default_direction(@kind, @sort)
    @custom_sort = @sort != "rank" || @direction != "asc" # anything but the ranking's own order
    sorted = ranking.entries_sorted_by(@sort, @direction)
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

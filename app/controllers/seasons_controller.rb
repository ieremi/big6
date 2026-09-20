class SeasonsController < ApplicationController
  # Past seasons never change and each season's tags are cached on their own
  # (keyed on that season's latest game update), so this can be long — a short
  # expiry would recompute every season at once, which is what used to exhaust
  # CPU/memory and get the instance restarted (502s).
  TAGS_CACHE_EXPIRY = 7.days

  def index
    # Only the columns the list needs: scorebook_data/scorebook_games are large
    # JSONB blobs (~20MB across all seasons) that nothing on this page reads.
    @seasons = Season.select(:id, :year, :term).order(year: :desc, term: :desc).to_a
    @games_counts = Game.group(:season_id).count
    @season_tags = season_tags_by_id(@seasons)

    @selected_tags = Array(params[:tags]) & SeasonTags::LABELS
    if @selected_tags.any?
      @seasons = @seasons.select do |season|
        labels = (@season_tags[season.id] || []).map(&:label)
        @selected_tags.all? { |t| labels.include?(t) }
      end
    end
  end

  def show
    @season = Season.find_by!(year: params[:year], term: params[:term])
    @games = @season.games.includes(:team0, :team1, :season).order(:played_on, :game_number)

    # The universities that played this season, and those chosen to narrow the
    # games to (nothing chosen: every game).
    @universities = University.where(id: @games.pluck(:team0_id, :team1_id).flatten.uniq).order(:position).to_a
    @selected_university_ids = Array(params[:university_ids]).map(&:to_i) & @universities.map(&:id)

    if request.format.symbol == :ics
      games = @games
      games = games.where(team0_id: @selected_university_ids).or(games.where(team1_id: @selected_university_ids)) if @selected_university_ids.any?
      cache_key = "season_ics/v1/#{@season.id}/#{@selected_university_ids.sort.join('-')}/#{games.maximum(:updated_at)&.to_i}"
      ics = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        calendar = IcsCalendar.new(name: @season.title)
        games.each { |game| IcsGameEvent.add_to(calendar, game) }
        calendar.to_ics
      end

      send_data ics, type: "text/calendar", filename: "#{@season.year}-#{@season.term}.ics", disposition: "attachment"
      return
    end

    season_weeks = SeasonWeeks.new(@games)
    @weeks = season_weeks.weeks_with(@selected_university_ids)
    @shown_game_count = @weeks.sum { |week| week.games.size }
    @prime_ministers = PrimeMinisterTerm.serving_between(*@games.map(&:played_on).minmax).to_a
    @gdp_per_capita = GdpPerCapitaYear.usd_for(@season.year)
    @tags = SeasonTags.new(@season).tags
    @attendance_trend = SeasonAttendanceTrend.new(@season)
  end

  def standings
    @season = Season.find_by!(year: params[:year], term: params[:term])
    @standings = Standings.new(@season)
  end

  def index_og_image
    send_data SiteOgImage.new(title: "Seasons").to_png, type: "image/png", disposition: "inline"
  end

  def og_image
    season = Season.find_by!(year: params[:year], term: params[:term])

    send_data OgImages.season(season, label: params[:label]), type: "image/png", disposition: "inline"
  end

  private

  # { season_id => [Tag, ...] } for the seasons that have games. Each season is
  # cached separately (one multi-read), so a warm request loads no game or
  # scorebook data at all; on a miss only that one season is loaded and
  # computed, keeping peak memory to a single season instead of every game
  # plus every season's JSONB at once.
  def season_tags_by_id(seasons)
    latest_update_by_season = Game.group(:season_id).maximum(:updated_at)
    season_id_by_key = seasons.filter_map do |season|
      updated_at = latest_update_by_season[season.id]
      [ "season_tags/v3/#{season.id}/#{updated_at.to_i}", season.id ] if updated_at
    end.to_h

    universities = nil
    tags_by_key = Rails.cache.fetch_multi(*season_id_by_key.keys, expires_in: TAGS_CACHE_EXPIRY) do |key|
      universities ||= University.order(:position).to_a
      SeasonTags.new(Season.find(season_id_by_key.fetch(key)), universities: universities).tags
    end

    season_id_by_key.to_h { |key, season_id| [ season_id, tags_by_key.fetch(key) ] }
  end
end

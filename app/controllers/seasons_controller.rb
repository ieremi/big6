class SeasonsController < ApplicationController
  TAGS_CACHE_EXPIRY = 6.hours

  def index
    @seasons = Season.order(year: :desc, term: :desc).to_a
    @games_counts = Game.group(:season_id).count

    # Both of these scan every season's full game history, so they're worth
    # computing together, once, behind a cache — previously attendance_totals
    # ran uncached on every request (parsing ~20MB of JSONB each time) and
    # season_tags recomputed with an N+1 (one query per season) on every
    # cache miss, which combined into occasional 502s under load.
    cache_key = "season_index_data/v1/#{Game.maximum(:updated_at)&.to_i}"
    data = Rails.cache.fetch(cache_key, expires_in: TAGS_CACHE_EXPIRY) do
      universities = University.order(:position).to_a
      games_by_season = Game.includes(:team0, :team1).order(:played_on, :game_number).group_by(&:season_id)

      attendance_totals = @seasons.each_with_object({}) do |season, totals|
        next if season.scorebook_games.blank?

        total = season.scorebook_games.sum do |g|
          value = g["attendance"].to_s.delete(",").strip
          value.match?(/\A\d+\z/) ? value.to_i : 0
        end
        totals[season.id] = total if total.positive?
      end

      season_tags = @seasons.each_with_object({}) do |season, tags|
        games = games_by_season[season.id] || []
        tags[season.id] = SeasonTags.new(season, games: games, universities: universities).tags
      end

      { attendance_totals: attendance_totals, season_tags: season_tags }
    end

    @attendance_totals = data[:attendance_totals]
    @season_tags = data[:season_tags]

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

    if request.format.symbol == :ics
      cache_key = "season_ics/v1/#{@season.id}/#{@games.maximum(:updated_at)&.to_i}"
      ics = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        calendar = IcsCalendar.new(name: @season.title)
        @games.each { |game| IcsGameEvent.add_to(calendar, game) }
        calendar.to_ics
      end

      send_data ics, type: "text/calendar", filename: "#{@season.year}-#{@season.term}.ics", disposition: "attachment"
      return
    end

    @weeks = SeasonWeeks.new(@games).weeks
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
    title = "#{season.year} #{season.term.capitalize}"
    subtitle = params[:label].presence
    stripe_colors = Standings.new(season).rows.map { |row| row.university.color }

    send_data SiteOgImage.new(title: title, subtitle: subtitle, stripe_colors: stripe_colors).to_png, type: "image/png", disposition: "inline"
  end
end

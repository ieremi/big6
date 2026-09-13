class SeasonsController < ApplicationController
  TAGS_CACHE_EXPIRY = 6.hours

  def index
    @seasons = Season.order(year: :desc, term: :desc)
    @games_counts = Game.group(:season_id).count
    @attendance_totals = @seasons.each_with_object({}) do |season, totals|
      next if season.scorebook_games.blank?

      total = season.scorebook_games.sum do |g|
        value = g["attendance"].to_s.delete(",").strip
        value.match?(/\A\d+\z/) ? value.to_i : 0
      end
      totals[season.id] = total if total.positive?
    end

    cache_key = "season_tags/v3/#{Game.maximum(:updated_at)&.to_i}"
    @season_tags = Rails.cache.fetch(cache_key, expires_in: TAGS_CACHE_EXPIRY) do
      @seasons.each_with_object({}) { |season, tags| tags[season.id] = SeasonTags.new(season).tags }
    end

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
      calendar = IcsCalendar.new(name: @season.title)
      @games.each { |game| IcsGameEvent.add_to(calendar, game) }
      send_data calendar.to_ics, type: "text/calendar", filename: "#{@season.year}-#{@season.term}.ics", disposition: "attachment"
      return
    end

    @weeks = SeasonWeeks.new(@games).weeks
    @tags = SeasonTags.new(@season).tags
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

class MatchupsController < ApplicationController
  CACHE_EXPIRY = 6.hours

  def index
    @universities = University.order(:position).to_a
    latest_season_id = Game.order(played_on: :desc, game_number: :desc).limit(1).pick(:season_id)

    @periods = {
      "5" => { since: 5.years.ago.to_date },
      "10" => { since: 10.years.ago.to_date },
      "20" => { since: 20.years.ago.to_date },
      "all" => {},
      "r" => { season_id: latest_season_id }
    }

    cache_key = "matchups_index_data/v2/#{latest_season_id}/#{Game.maximum(:updated_at)&.to_i}"
    data = Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) { build_data }

    @cells = data[:cells]
    @row_avg = data[:row_avg]
    @row_sum = data[:row_sum]
    @grand_attendance = data[:grand_attendance]
  end

  def show
    @team0 = University.find_by!(slug: params[:team0_slug])
    @team1 = University.find_by!(slug: params[:team1_slug])
    @matchup = Matchup.new(@team0, @team1)

    if params[:year] && params[:term]
      @season = Season.find_by!(year: params[:year], term: params[:term])
    elsif params[:year]
      @year = params[:year]
    end

    if @season && params[:game_number]
      @game = Game.includes(:team0, :team1, :season)
        .where(team0_id: [ @team0.id, @team1.id ], team1_id: [ @team0.id, @team1.id ])
        .where(season_id: @season.id, game_number: params[:game_number])
        .first!

      if request.format.symbol == :ics
        calendar = IcsCalendar.new(name: "#{@game.team0.short_name} vs #{@game.team1.short_name}")
        IcsGameEvent.add_to(calendar, @game)
        send_data calendar.to_ics, type: "text/calendar", filename: "game-#{@game.id}.ics", disposition: "attachment"
        return
      end

      @scoreboard = GameScoreboard.new(@game)
      @official_scoreboard = LeagueOfficialScoreboard.new(@game)
      render "games/show" and return
    end

    @sort = %w[season card].include?(params[:sort]) ? params[:sort] : nil
    @sort_direction = params[:direction] == "desc" ? "desc" : "asc"
    @games = sort_games_array(@matchup.games_for(season: @season, year: @year), @sort, @sort_direction)

    if @season.nil? && @year.nil?
      latest_season_id = Game.order(played_on: :desc, game_number: :desc).limit(1).pick(:season_id)
      @periods = {
        "all" => {},
        "20" => { since: 20.years.ago.to_date },
        "10" => { since: 10.years.ago.to_date },
        "5" => { since: 5.years.ago.to_date },
        "r" => { season_id: latest_season_id }
      }
      @game_periods = @games.each_with_object({}) { |g, h| h[g.id] = @matchup.period_keys_for(g, @periods) }
      @initial_period = @periods.key?(params[:period]) ? params[:period] : "all"
    end
  end

  def index_og_image
    send_data SiteOgImage.new(title: "Matchups").to_png, type: "image/png", disposition: "inline"
  end

  PERIOD_LABELS = {
    "all" => "All-time",
    "20" => "Last 20 Years",
    "10" => "Last 10 Years",
    "5" => "Last 5 Years",
    "r" => "Latest Season"
  }.freeze

  def matchup_og_image
    team0 = University.find_by!(slug: params[:team0_slug])
    team1 = University.find_by!(slug: params[:team1_slug])
    matchup = Matchup.new(team0, team1)

    season = nil
    year = nil
    if params[:year] && params[:term]
      season = Season.find_by!(year: params[:year], term: params[:term])
    elsif params[:year]
      year = params[:year]
    end

    if season || year
      opts = season ? { season_id: season.id } : { year: year }
      subtitle = season ? "for #{season.year} #{season.term.capitalize}" : "for #{year}"
    else
      period = PERIOD_LABELS.key?(params[:period]) ? params[:period] : "all"
      opts = period_opts(period)
      subtitle = "for #{PERIOD_LABELS.fetch(period)}"
    end

    wins0 = matchup.wins(team0, **opts)
    wins1 = matchup.wins(team1, **opts)

    send_data MatchupOgImage.new(team0, team1, wins0: wins0, wins1: wins1, subtitle: subtitle).to_png, type: "image/png", disposition: "inline"
  end

  private

  def period_opts(key)
    case key
    when "20" then { since: 20.years.ago.to_date }
    when "10" then { since: 10.years.ago.to_date }
    when "5" then { since: 5.years.ago.to_date }
    when "r" then { season_id: Game.order(played_on: :desc, game_number: :desc).limit(1).pick(:season_id) }
    else {}
    end
  end

  def sort_games_array(games, sort, direction)
    return games unless sort

    multiplier = direction == "desc" ? -1 : 1

    case sort
    when "season"
      games.sort_by { |g| [ g.season.year * multiplier, (g.season.term == "autumn" ? 1 : 0) * multiplier, g.played_on, g.game_number ] }
    when "card"
      games.sort_by do |g|
        lo, hi = [ g.team0.position, g.team1.position ].sort
        [ lo * multiplier, hi * multiplier, g.played_on, g.game_number ]
      end
    end
  end

  def build_data
    matchups = {}
    @universities.combination(2).each do |team0, team1|
      matchup = Matchup.new(team0, team1)
      matchups[[ team0.id, team1.id ]] = matchup
      matchups[[ team1.id, team0.id ]] = matchup
    end

    cells = {}
    @universities.each do |a|
      @universities.each do |b|
        next if a == b

        matchup = matchups[[ a.id, b.id ]]
        cells[[ a.id, b.id ]] = {
          "rate" => @periods.transform_values { |opts| matchup.percentage(a, **opts) },
          "attendance_avg" => @periods.transform_values { |opts| matchup.average_attendance(**opts) },
          "attendance_sum" => @periods.transform_values { |opts| matchup.total_attendance(**opts) }
        }
      end
    end

    row_avg = {}
    row_sum = {}
    @universities.each do |university|
      opponents = @universities - [ university ]

      row_avg[university.id] = {
        "rate" => @periods.transform_values do |opts|
          row_average(opponents.filter_map { |o| matchups[[ university.id, o.id ]].percentage(university, **opts) })
        end,
        "attendance" => @periods.transform_values do |opts|
          row_average(opponents.filter_map { |o| matchups[[ university.id, o.id ]].average_attendance(**opts) })
        end
      }

      row_sum[university.id] = {
        "attendance" => @periods.transform_values do |opts|
          row_sum_of(opponents.filter_map { |o| matchups[[ university.id, o.id ]].total_attendance(**opts) })
        end
      }
    end

    { cells: cells, row_avg: row_avg, row_sum: row_sum, grand_attendance: grand_attendance }
  end

  def grand_attendance
    @periods.transform_values do |opts|
      scope = Game.all
      scope = scope.where(season_id: opts[:season_id]) if opts[:season_id]
      scope = scope.where("played_on >= ?", opts[:since]) if opts[:since]
      values = scope.where.not(attendance: nil).pluck(:attendance)

      { "avg" => values.empty? ? nil : values.sum / values.size, "sum" => values.empty? ? nil : values.sum }
    end
  end

  def row_average(values)
    values.empty? ? nil : values.sum / values.size
  end

  def row_sum_of(values)
    values.empty? ? nil : values.sum
  end
end

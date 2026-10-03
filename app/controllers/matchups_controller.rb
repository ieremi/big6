class MatchupsController < ApplicationController
  include GameSortable

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

    cache_key = "matchups_index_data/v3/#{latest_season_id}/#{Game.maximum(:updated_at)&.to_i}"
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

      @game_members_by_university = @game.game_members.includes(:player).group_by(&:university_id)
      @played_player_ids = @game.played_player_ids if @game_members_by_university.present?
      # In id order, which is the order GameStatsImport inserted them in: Scorebook's
      # own, batters in batting order (each substitute after the one replaced) and
      # pitchers in the order they pitched.
      @batting_lines_by_university = @game.batting_lines.includes(:player).order(:id).group_by(&:university_id)
      @pitching_lines_by_university = @game.pitching_lines.includes(:player).order(:id).group_by(&:university_id)
      @scoreboard = GameScoreboard.new(@game)
      @official_scoreboard = LeagueOfficialScoreboard.new(@game)
      # Scorebook only has GameMember lists once it's fully processed a
      # game, well after it's finished — so the fallback to the league
      # site's box score (see LeagueOfficialLineup) is needed for a while
      # after the game ends too, not just while it's in progress; it
      # naturally shows nothing once Scorebook's own list arrives (or if
      # the box score was never scraped, e.g. the game hasn't started).
      if @game_members_by_university.blank?
        @official_lineup = LeagueOfficialLineup.new(@game)
      end
      @roster_diffs = RosterDiff.for_game(@game, members_by_university: @game_members_by_university, official_lineup: @official_lineup)
      render "games/show" and return
    end

    read_game_sort
    @games = sort_games_array(@matchup.games_for(season: @season, year: @year), @sort_order)

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

  def matchup_og_image
    team0 = University.find_by!(slug: params[:team0_slug])
    team1 = University.find_by!(slug: params[:team1_slug])
    season = Season.find_by!(year: params[:year], term: params[:term]) if params[:year] && params[:term]
    year = params[:year] if params[:year] && !season

    send_data OgImages.matchup(team0, team1, season: season, year: year, period: params[:period]), type: "image/png", disposition: "inline"
  end

  private

  # The same orders as GameSortable#apply_game_sort, for a list already loaded:
  # each key in turn, then date order. Blanks (a game not held has no round)
  # come last whichever way.
  def sort_games_array(games, order)
    return games if order.empty?

    games.sort_by do |game|
      keys = order.flat_map do |key|
        sign = key.desc? ? -1 : 1
        game_sort_values(game, key.column).flat_map { |value| [ value.nil? ? 1 : 0, value.to_i * sign ] }
      end
      [ *keys, game.played_on.jd, game.game_number || Float::INFINITY ]
    end
  end

  # The values a column sorts a game by, most significant first.
  def game_sort_values(game, column)
    case column
    when "season" then [ game.season.year, game.season.term == "autumn" ? 1 : 0 ]
    when "date" then [ game.played_on.jd, game.game_number ]
    when "round" then [ game.game_number ]
    when "card" then [ game.team0.position, game.team1.position ].sort
    when "attendance" then [ game.attendance ]
    end
  end

  def build_data
    # One query for every game, instead of Matchup.new doing its own
    # (games + team0 + team1 + season) query per pair — 15 pairs' worth
    # otherwise. :season isn't preloaded since nothing on this page's path
    # needs it (only Matchup#games_for/scoped_games's year: branch does,
    # neither of which build_data exercises) — it would otherwise pull in
    # every season's full scorebook_games JSONB (tens of MB) for nothing.
    all_games = Game.includes(:team0, :team1).order(:played_on, :game_number).to_a
    games_by_pair = all_games.group_by { |g| [ g.team0_id, g.team1_id ].sort }

    matchups = {}
    @universities.combination(2).each do |team0, team1|
      games = games_by_pair[[ team0.id, team1.id ].sort] || []
      matchup = Matchup.new(team0, team1, games: games)
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
          "attendance_sum" => @periods.transform_values { |opts| matchup.total_attendance(**opts) },
          "attendance_avg_weekend" => @periods.transform_values { |opts| matchup.average_attendance(**opts, weekends_only: true) },
          "attendance_sum_weekend" => @periods.transform_values { |opts| matchup.total_attendance(**opts, weekends_only: true) }
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
        end,
        "attendance_weekend" => @periods.transform_values do |opts|
          row_average(opponents.filter_map { |o| matchups[[ university.id, o.id ]].average_attendance(**opts, weekends_only: true) })
        end
      }

      row_sum[university.id] = {
        "attendance" => @periods.transform_values do |opts|
          row_sum_of(opponents.filter_map { |o| matchups[[ university.id, o.id ]].total_attendance(**opts) })
        end,
        "attendance_weekend" => @periods.transform_values do |opts|
          row_sum_of(opponents.filter_map { |o| matchups[[ university.id, o.id ]].total_attendance(**opts, weekends_only: true) })
        end
      }
    end

    { cells: cells, row_avg: row_avg, row_sum: row_sum, grand_attendance: grand_attendance(all_games) }
  end

  def grand_attendance(all_games)
    @periods.transform_values do |opts|
      scoped = all_games
      scoped = scoped.select { |g| g.season_id == opts[:season_id] } if opts[:season_id]
      scoped = scoped.select { |g| g.played_on >= opts[:since] } if opts[:since]
      values = scoped.filter_map(&:attendance)
      weekend_values = scoped.select(&:weekend?).filter_map(&:attendance)

      {
        "avg" => row_average(values), "sum" => row_sum_of(values),
        "avg_weekend" => row_average(weekend_values), "sum_weekend" => row_sum_of(weekend_values)
      }
    end
  end

  def row_average(values)
    values.empty? ? nil : values.sum / values.size
  end

  def row_sum_of(values)
    values.empty? ? nil : values.sum
  end
end

# The PNG for each kind of OG image, built from the records it describes. The
# site's pages and the Web API both serve these, so they are the same image
# wherever it is fetched from.
module OgImages
  module_function

  MATCHUP_PERIOD_LABELS = {
    "all" => "All-time",
    "20" => "Last 20 Years",
    "10" => "Last 10 Years",
    "5" => "Last 5 Years",
    "r" => "Latest Season"
  }.freeze

  # A university's all-time record.
  def university(university)
    record = TeamRecord.new(university)

    UniversityStatsOgImage.new(
      university,
      streak_length: record.longest_streak&.length,
      rate: record.percentage,
      subtitle: "for All Seasons"
    ).to_png
  end

  # A season, in the colours of its standings order; label is an optional subtitle.
  def season(season, label: nil)
    stripe_colors = Standings.new(season).rows.map { |row| row.university.color }

    SiteOgImage.new(title: "#{season.year} #{season.term.capitalize}", subtitle: label.presence, stripe_colors: stripe_colors).to_png
  end

  def game(game)
    GameOgImage.new(game).to_png
  end

  # Two universities' record against each other: within one season, within one
  # year, or over a period (a key of MATCHUP_PERIOD_LABELS; anything else is "all").
  def matchup(team0, team1, season: nil, year: nil, period: nil)
    matchup = Matchup.new(team0, team1)

    if season || year
      options = season ? { season_id: season.id } : { year: year }
      subtitle = season ? "for #{season.year} #{season.term.capitalize}" : "for #{year}"
    else
      period = MATCHUP_PERIOD_LABELS.key?(period) ? period : "all"
      options = matchup_period_options(period)
      subtitle = "for #{MATCHUP_PERIOD_LABELS.fetch(period)}"
    end

    MatchupOgImage.new(team0, team1, wins0: matchup.wins(team0, **options), wins1: matchup.wins(team1, **options), subtitle: subtitle).to_png
  end

  def matchup_period_options(key)
    case key
    when "20" then { since: 20.years.ago.to_date }
    when "10" then { since: 10.years.ago.to_date }
    when "5" then { since: 5.years.ago.to_date }
    when "r" then { season_id: Game.order(played_on: :desc, game_number: :desc).limit(1).pick(:season_id) }
    else {}
    end
  end
end

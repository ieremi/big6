require "date"

SCOREBOOK_TEAM_SLUGS = {
  1 => "waseda",
  2 => "keio",
  3 => "meiji",
  4 => "hosei",
  5 => "tokyo",
  6 => "rikkio"
}.freeze

universities_by_slug = University.where(slug: SCOREBOOK_TEAM_SLUGS.values).index_by(&:slug)

Season.where.not(scorebook_games: nil).find_each do |season|
  pair_round_counts = Hash.new(0)

  season.scorebook_games.each do |info|
    next if info["topTeamId"].nil? || info["bottomTeamId"].nil?

    # Import every scheduled game, even ones that haven't been played yet
    # (nil scores) — this lets the site show the upcoming schedule. As a game
    # goes from scheduled -> in progress -> final, re-running this script
    # picks up each update via the find_or_initialize_by below.
    team0 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("topTeamId")))
    team1 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("bottomTeamId")))

    # info["round"] (e.g. "3回戦") is the game's position within that pair's series;
    # info["gameOrder"] is unrelated (position within that day's schedule for doubleheaders).
    # A handful of games (e.g. a championship playoff) don't carry a "N回戦" round label,
    # so fall back to continuing the pair's own sequence for the season.
    pair_key = [ team0.id, team1.id ].sort
    match = info["round"].to_s.match(/(\d+)回戦/)
    game_number = match ? match[1].to_i : pair_round_counts[pair_key] + 1
    pair_round_counts[pair_key] = game_number

    game = Game.find_or_initialize_by(
      season: season,
      team0: team0,
      team1: team1,
      played_on: Date.parse(info.fetch("gameDay"))
    )

    attendance = info["attendance"].to_s.delete(",").strip

    game.game_number = game_number
    game.team0_score = info["runsTotalTop"]&.to_i
    game.team1_score = info["runsTotalBottom"]&.to_i
    game.scorebook_game_id = info["id"]
    game.game_order = info["gameOrder"]
    game.attendance = attendance.to_i if attendance.match?(/\A\d+\z/)
    game.save!
  end
end

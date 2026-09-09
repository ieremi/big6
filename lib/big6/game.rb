require "date"

SCOREBOOK_TEAM_SLUGS = {
  1 => "waseda",
  2 => "keio",
  3 => "meiji",
  4 => "hosei",
  5 => "tokyo",
  6 => "rikkyo"
}.freeze

universities_by_slug = University.where(slug: SCOREBOOK_TEAM_SLUGS.values).index_by(&:slug)

Season.where.not(scorebook_games: nil).find_each do |season|
  season.scorebook_games.each do |info|
    next if info["runsTotalTop"].nil? || info["runsTotalBottom"].nil?
    next if info["topTeamId"].nil? || info["bottomTeamId"].nil?

    team0 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("topTeamId")))
    team1 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("bottomTeamId")))

    game = Game.find_or_initialize_by(
      season: season,
      team0: team0,
      team1: team1,
      played_on: Date.parse(info.fetch("gameDay")),
      game_number: info["gameOrder"] || 1
    )

    game.team0_score = info["runsTotalTop"].to_i
    game.team1_score = info["runsTotalBottom"].to_i
    game.save!
  end
end

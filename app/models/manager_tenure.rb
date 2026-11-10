# A manager's (監督) time at a university, for the article on 小宮山悟's at 早大
# (/articles/komiyama-record): the university's league record over the seasons
# from the one the manager took over (wins, losses and draws against each
# opponent, and the cards won and lost), the seasons it won, its longest run of
# titles, how many players were in the club while the manager was, and each
# year's leading batters and pitchers (leaders).
#
# Worked out from the games as they come in, so it follows the seasons still
# being played. Only league games (counted_in_stats): a 優勝決定戦 playoff is
# left out of the records, though the title it decides counts. A card is won
# with two wins (in the 2020 and 2021 seasons, with more wins than the other
# side, as StreakRecords counts them).
class ManagerTenure
  # A year's leading players: batters (BattingLine::Totals) by batting average
  # among those reaching the league's minimum over the year's games (3.1 plate
  # appearances a team game), and pitchers (PitchingLine::Totals) by innings.
  Leaders = Data.define(:year, :batters, :pitchers)
  Leader = Data.define(:player, :totals)

  # The record against one opponent.
  Opponent = Data.define(:university, :wins, :losses, :draws, :cards_won, :cards_lost)

  attr_reader :university

  # from: the first season, [year, "spring" or "autumn"].
  def initialize(university, from:)
    @university = university
    @from_year, @from_term = from
  end

  # The seasons from the first, with games, oldest first.
  def seasons
    @seasons ||= Season.where(year: @from_year..).where(id: Game.select(:season_id)).to_a
      .reject { |season| season.year == @from_year && @from_term == "autumn" && season.term == "spring" }
      .sort_by { |season| [ season.year, season.term == "spring" ? 0 : 1 ] }
  end

  def by_opponent
    @by_opponent ||= begin
      games = Game.where(season_id: seasons.map(&:id), counted_in_stats: true).where("team0_id = :id OR team1_id = :id", id: @university.id)
        .includes(:season).select(&:decided?)
      games.group_by { |game| game.team0_id == @university.id ? game.team1_id : game.team0_id }.map do |opponent_id, list|
        wins, losses, draws = record_of(list)
        cards = list.group_by(&:season).map do |season, card|
          season.points_season? ? StreakRecords.card_majority(card) : StreakRecords.card_winner(card)
        end
        Opponent.new(university: University.find(opponent_id), wins:, losses:, draws:,
          cards_won: cards.count(@university.id), cards_lost: cards.count { |winner| winner && winner != @university.id })
      end.sort_by { |opponent| opponent.university.position }
    end
  end

  # Wins, losses and draws over all the opponents.
  def total
    %i[wins losses draws].map { |key| by_opponent.sum(&key) }
  end

  # The seasons the university won (SeasonChampion), oldest first.
  def titles
    @titles ||= seasons.select { |season| SeasonChampion.of(season) == @university }
  end

  # The longest run of titles in a row, as its seasons (the latest if several are as long).
  def longest_run
    runs = seasons.chunk_while { |a, b| titles.include?(a) && titles.include?(b) }.select { |run| titles.include?(run.first) }
    runs.max_by { |run| [ run.size, run.last.year ] } || []
  end

  # The players (not managers or staff, as the 名鑑 lists them) in the club while
  # the manager was: those who entered from four years before the first season
  # (still there in its spring) up to now.
  def players
    Player.where(university: @university, role: "選手", enter_year: (@from_year - 3)..)
  end

  # Each year's leaders, oldest first: count of each (3 batters and 3 pitchers),
  # from the year's box scores (league games only).
  def leaders(count: 3)
    seasons.group_by(&:year).map do |year, list|
      games = Game.where(season_id: list.map(&:id), counted_in_stats: true).where("team0_id = :id OR team1_id = :id", id: @university.id)
      minimum = (BattingLine.where(game_id: games.select(:id)).distinct.count(:game_id) * PlayerRanking::LEAGUE_PA_PER_GAME_TENTHS + 5) / 10
      batters = totals_by_player(BattingLine, games).select { |_, totals| totals.pa >= minimum && totals.average }
        .sort_by { |player, totals| [ -totals.average, -totals.hits, player.name ] }.first(count)
      pitchers = totals_by_player(PitchingLine, games).sort_by { |player, totals| [ -totals.outs, player.name ] }.first(count)
      Leaders.new(year:, batters: batters.map { |player, totals| Leader.new(player:, totals:) },
        pitchers: pitchers.map { |player, totals| Leader.new(player:, totals:) })
    end
  end

  private

  # { Player => Totals } of the university's players over the games.
  def totals_by_player(line_class, games)
    lines = line_class.where(game_id: games.select(:id), university_id: @university.id).includes(:player).to_a
    lines.group_by(&:player).transform_values { |player_lines| line_class.totals(player_lines) }
  end

  def record_of(games)
    results = games.map do |game|
      ours, theirs = game.team0_id == @university.id ? [ game.team0_score, game.team1_score ] : [ game.team1_score, game.team0_score ]
      ours <=> theirs
    end
    [ results.count(1), results.count(-1), results.count(0) ]
  end
end

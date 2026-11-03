# 首位打者のゆくえ: for a season being played, whether a player at the top of
# the batting average (as the league ranks it: PlayerRanking with the league's
# minimum) can still be passed, and how — for an article that follows one
# player's title (/articles/echigo-batting-title).
#
# A player can be passed only by a batter whose university still has games to
# play: one already above the player with none left has passed them for good.
# For each batter who could, the hits they would need in their remaining games
# to finish above the player, at their own at-bats a game so far (the number
# of games left being a range: a card not yet won by either side goes to a
# 3回戦 when it stands at one win each). A batter counts only when they would
# reach the league's minimum (規定打席) at that pace, and figures are compared
# as the league shows them, to three decimals: equal there, the title is
# shared, as it has been (1952 spring, 2006 spring).
#
# The player's own figure is final once their university has no games left and
# every game it played has its box score (Scorebook takes a day or so); until
# then pending_games lists those still to come in.
class BattingTitleRace
  # A batter who could pass the player: their totals so far, the games their
  # university may have left (a Range), and for each number of games in it a
  # Need (nil when they couldn't reach the minimum at their pace).
  Rival = Data.define(:player, :totals, :games_left, :needs)

  # What a rival needs in so many games: at_bats at their pace, and the fewest
  # hits in them that would put them above the player (nil when even a hit in
  # every one wouldn't), with the average they would then have.
  Need = Data.define(:games, :at_bats, :hits, :average)

  def initialize(season, player:)
    @season = season
    @player = player
  end

  attr_reader :season, :player

  # The player's place in the league's ranking (a PlayerRanking::Entry), or nil
  # when they haven't reached the minimum.
  def entry
    @entry ||= league_ranking.entries.find { |entry| entry.player.id == @player.id }
  end

  def average
    entry&.totals&.average
  end

  # Batters above the player whose universities have no games left: they stay above.
  def passed_for_good
    return [] unless entry

    league_ranking.entries.select { |other| shown(other.totals.average) > shown(average) && games_left(other.player.university).max.zero? }
  end

  # The games this season the player's university has finished without their box
  # score in yet: until they are, the player's figure isn't final.
  def pending_games
    @pending_games ||= Game.finished.where(season: @season, counted_in_stats: true)
      .where("team0_id = :id OR team1_id = :id", id: @player.university_id)
      .where.not(id: BattingLine.select(:game_id)).order(:played_on).to_a
  end

  def final?
    entry.present? && games_left(@player.university).max.zero? && pending_games.empty?
  end

  # The batters who could still pass the player, the closest first.
  def rivals
    return [] unless entry

    @rivals ||= every_batter.filter_map { |other| rival_for(other) }
      .sort_by { |rival| [ rival.needs.compact.filter_map(&:hits).min || 99, -rival.totals.average.to_f ] }
  end

  # The fewest and most games a university may have left: those still to play,
  # and a 3回戦 for each card it plays whose first two games split.
  def games_left(university)
    @games_left ||= {}
    @games_left[university.id] ||= begin
      games = Game.where(season: @season, counted_in_stats: true).where("team0_id = :id OR team1_id = :id", id: university.id).to_a
      open = games.select { |game| game.scheduled? || game.in_progress? }
      extra = open.group_by { |game| [ game.team0_id, game.team1_id ].sort }.sum do |pair, pair_games|
        held = games.count { |game| game.decided? && [ game.team0_id, game.team1_id ].sort == pair }
        [ 3 - held - pair_games.size, 0 ].max
      end
      open.size..(open.size + extra)
    end
  end

  private

  def league_ranking
    @league_ranking ||= PlayerRanking.new("batting", season: @season, minimum: PlayerRanking::LEAGUE, order_by: "average")
  end

  # Everyone who has batted this season, with their totals.
  def every_batter
    PlayerRanking.new("batting", season: @season, minimum: 0).entries
  end

  def rival_for(other)
    return nil if other.player.id == @player.id || other.totals.games.zero?

    left = games_left(other.player.university)
    return nil if left.max.zero?

    needs = left.map { |games| need(other.player.university, other.totals, games) }
    return nil if needs.compact.none?(&:hits)

    Rival.new(player: other.player, totals: other.totals, games_left: left, needs:)
  end

  # What the batter needs in the games, at their pace, or nil when they wouldn't
  # reach the minimum.
  def need(university, totals, games)
    plate_appearances = totals.pa + (totals.pa.to_f / totals.games * games).round
    return nil if plate_appearances < PlayerRanking.league_minimum_for("batting", team_games(university) + games)

    at_bats = (totals.ab.to_f / totals.games * games).round
    hits = (0..at_bats).find { |count| shown((totals.hits + count).to_f / (totals.ab + at_bats)) > shown(average) }
    Need.new(games:, at_bats:, hits:, average: hits && (totals.hits + hits).to_f / (totals.ab + at_bats))
  end

  # A university's games so far with their box score in: those the minimum counts.
  def team_games(university)
    Game.finished.where(season: @season, counted_in_stats: true).where("team0_id = :id OR team1_id = :id", id: university.id)
      .where(id: BattingLine.select(:game_id)).count
  end

  # A figure as the league shows it, to three decimals.
  def shown(value)
    value.to_f.round(3)
  end
end

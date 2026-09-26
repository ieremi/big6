# Checks the games table (as imported from Scorebook) for what can't be right,
# or needs a look: a university with two games on one day, a game whose two
# sides are the same university, a run of games days apart against different
# opponents, and each pair's series in a season (round numbers repeated or
# missing, games after one side already has 2 wins, a series over with no one
# at 2 wins), and the pairs of each season. Nothing is changed; the admin pages
# list the findings (Admin::GameChecksController), and a finding looked at and
# found fine is marked so (GameCheckReview) and left out after.
#
# Many findings are the rules of the day rather than errors (the schedules of
# the 1940s, playoffs, replays), which is why a person decides. The seasons of
# 2020, played in other formats (SPECIAL_FORMATS), are left out of the series
# checks and of the runs of opponents.
#
# Only the columns the checks need are read: a Game row also carries JSON, and
# a Season a lot more.
class GameDataCheck
  KINDS = {
    "same_day" => "同じ日に同じ大学の試合が2つ",
    "same_team" => "両チームが同じ大学",
    "opponent_change" => "連戦（2日以内）で相手が変わる",
    "round_duplicate" => "カードの中で回戦番号が重複",
    "round_gap" => "カードの中で回戦番号が抜けている",
    "after_decided" => "2勝した大学が出たあとも試合がある",
    "undecided" => "どちらも2勝せずにカードが終わっている",
    "pair_count" => "シーズンのカード数が合わない"
  }.freeze

  # Seasons not played as best-of-three series: a single round robin in the
  # spring of 2020, and two games a pair (points for wins and ties) in its autumn.
  SPECIAL_FORMATS = { [ 2020, "spring" ] => "1試合総当たり", [ 2020, "autumn" ] => "2試合制" }.freeze

  # A finding: its kind (a key of KINDS), a key that stays the same from one
  # check to the next, the season, what it is about in words, and the games.
  Finding = Struct.new(:kind, :key, :season, :message, :games, keyword_init: true)

  def findings
    @findings ||= [
      *same_day, *same_team, *opponent_changes, *series_findings, *pair_counts
    ].sort_by { |finding| [ KINDS.keys.index(finding.kind), finding.games.map(&:played_on).min || Date.new(1900), finding.key ] }
  end

  private

  def games
    @games ||= begin
      seasons = Season.select(:id, :year, :term).index_by(&:id)
      Game.select(:id, :season_id, :team0_id, :team1_id, :played_on, :game_number, :game_status, :team0_score, :team1_score,
          :counted_in_stats, :scorebook_game_id).to_a.each do |game|
        game.association(:season).target = seasons[game.season_id]
        game.association(:team0).target = universities[game.team0_id]
        game.association(:team1).target = universities[game.team1_id]
      end
    end
  end

  # The universities by id, loaded once: names are looked up for every finding.
  def universities
    @universities ||= University.all.index_by(&:id)
  end

  def held
    @held ||= games.select(&:held?)
  end

  def label(game)
    "#{game.played_on} #{game.team0.short_name} vs #{game.team1.short_name} #{game.game_number ? "#{game.game_number}回戦" : game.status_label}"
  end

  # Each held game once for each of its sides: [university id, game, opponent id]
  # (once only for a game whose two sides are the same university).
  def sides
    @sides ||= held.flat_map { |game| [ [ game.team0_id, game, game.team1_id ], [ game.team1_id, game, game.team0_id ] ].uniq { |team, _, _| team } }
  end

  def university_name(id)
    universities.fetch(id).short_name
  end

  def same_day
    sides.group_by { |team, game, _| [ team, game.played_on ] }.filter_map do |(team, day), rows|
      next if rows.size < 2

      day_games = rows.map { |_, game, _| game }
      Finding.new(kind: "same_day", key: "same_day #{team} #{day}", season: day_games.first.season,
        message: "#{university_name(team)}が#{day}に#{day_games.size}試合", games: day_games)
    end
  end

  def same_team
    games.select { |game| game.team0_id == game.team1_id }.map do |game|
      Finding.new(kind: "same_team", key: "same_team #{game.id}", season: game.season,
        message: "#{game.team0.short_name} vs #{game.team1.short_name}", games: [ game ])
    end
  end

  # Two games of a university in one season within 2 days of each other, against
  # different opponents: a weekend's games are one pair's series.
  def opponent_changes
    sides.group_by(&:first).flat_map do |team, rows|
      rows.sort_by { |_, game, _| [ game.played_on, game.game_number.to_i ] }.each_cons(2).filter_map do |(_, a, opponent_a), (_, b, opponent_b)|
        next unless a.season_id == b.season_id && opponent_a != opponent_b && (b.played_on - a.played_on).between?(0, 2)
        next if special_format?(a.season)

        Finding.new(kind: "opponent_change", key: "opponent_change #{team} #{a.id} #{b.id}", season: a.season,
          message: "#{university_name(team)}：#{a.played_on} は#{university_name(opponent_a)}、#{b.played_on} は#{university_name(opponent_b)}", games: [ a, b ])
      end
    end
  end

  # Each pair's games in each season, in the order played.
  def series_findings
    held.group_by { |game| [ game.season_id, [ game.team0_id, game.team1_id ].sort ] }.flat_map do |(season_id, pair), series|
      season = series.first.season
      next [] if special_format?(season)

      series = series.sort_by { |game| [ game.played_on, game.game_number.to_i ] }
      key = "#{season_id} #{pair.join("-")}"
      name = pair.map { |id| universities.fetch(id) }.sort_by(&:position).map(&:short_name).join("-")
      rounds = series.map(&:game_number).compact
      found = []

      if rounds.size != rounds.uniq.size
        found << Finding.new(kind: "round_duplicate", key: "round_duplicate #{key}", season: season, message: "#{name}：回戦 #{rounds.join(", ")}", games: series)
      elsif rounds.any? && rounds.sort != (1..rounds.max).to_a
        found << Finding.new(kind: "round_gap", key: "round_gap #{key}", season: season, message: "#{name}：回戦 #{rounds.join(", ")}", games: series)
      end

      wins = Hash.new(0)
      series.select(&:counted_in_stats).each do |game|
        if wins.values.max.to_i >= 2
          found << Finding.new(kind: "after_decided", key: "after_decided #{key}", season: season,
            message: "#{name}：#{wins.map { |team, n| "#{university_name(team)}#{n}勝" }.join("・")}のあとに #{label(game)}", games: series)
          break
        end
        wins[game_winner(game)] += 1 if game_winner(game)
      end

      if series_over?(series) && wins.values.max.to_i < 2 && series.any?(&:decided?)
        found << Finding.new(kind: "undecided", key: "undecided #{key}", season: season,
          message: "#{name}：#{wins.empty? ? "勝敗なし" : wins.map { |team, n| "#{university_name(team)}#{n}勝" }.join("・")}（#{series.size}試合）", games: series)
      end

      found
    end
  end

  def special_format?(season)
    SPECIAL_FORMATS.key?([ season.year, season.term ])
  end

  def game_winner(game)
    return nil unless game.decided?

    if game.team0_score > game.team1_score then game.team0_id
    elsif game.team1_score > game.team0_score then game.team1_id
    end
  end

  # Whether a series can't go on: all its games played (or called off) and its
  # season over, not the latest one with games.
  def series_over?(series)
    series.all? { |game| game.finished? || game.not_held? } && series.first.season_id != latest_season_id
  end

  def latest_season_id
    @latest_season_id ||= games.max_by(&:played_on)&.season_id
  end

  # The pairs of a season: every university against every other once.
  def pair_counts
    held.group_by(&:season).filter_map do |season, season_games|
      teams = season_games.flat_map { |game| [ game.team0_id, game.team1_id ] }.uniq
      pairs = season_games.map { |game| [ game.team0_id, game.team1_id ].sort }.uniq
      expected = teams.size * (teams.size - 1) / 2
      next if pairs.size == expected

      Finding.new(kind: "pair_count", key: "pair_count #{season.id}", season: season,
        message: "#{teams.size}校でカード #{pairs.size}（本来 #{expected}）", games: [])
    end
  end
end

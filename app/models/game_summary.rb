# A game told in a few plain sentences (試合の要約), at the top of its page and
# as its description: who beat whom and by what score, on which day and where,
# extra innings and walk-off wins, the winning and losing pitchers, the home
# runs, the attendance, the weather, where the card stands afterwards (and the
# 勝ち点 it won), a season's only win or loss, and in the second half of a
# season how the game moved each side's chance of the title (ChampionshipOdds),
# or that it decided the title, with how many seasons in a row
# (SeasonChampion), and the other runs of seasons in a row it decided or ended
# (StreakRecords: 「これで明大の10季連続の2位以上が決まった」), and what it brought
# back after a long while (「これで東大の1981年春以来、92季ぶりのAクラスが決まった」).
#
# Written for people and for search engines and AI search alike, which quote
# a sentence more readily than a scoreboard. Every fact comes from the data the
# page shows (the game, its scoreboard, its box score), and a fact that isn't
# there is left out rather than guessed. The title odds are the one estimate,
# and their sentence says how they are worked out.
#
# The card's standing is told as a count of wins (「このカードは慶大の2勝1敗」),
# and 勝ち点 only for the seasons ranked by it (Season#ranked?): the formats of
# some seasons (2020's one-game and two-game cards, and many before the war)
# don't award it the usual way.
class GameSummary
  WEEKDAYS = %w[日 月 火 水 木 金 土].freeze

  # scoreboard is what the page shows: Scorebook's (GameScoreboard), or the
  # league site's provisional one (LeagueOfficialScoreboard) until it has one.
  def initialize(game, scoreboard:)
    @game = game
    @scoreboard = scoreboard
  end

  def sentences
    @sentences ||= if @game.decided?
      [ result, pitchers, home_runs, crowd_and_time, card_standing, only_win_or_loss, title_race, streaks ].compact
    elsif @game.in_progress?
      [ "#{event_name}、#{teams_label}は#{date_label}#{" #{stadium}で" if stadium}試合中。" ]
    elsif @game.scheduled?
      [ "#{event_name}、#{teams_label}は#{date_label}に行われる予定。" ]
    else
      [ "#{event_name}、#{teams_label}（#{date_label}）は#{@game.status_label}となった。" ]
    end
  end

  def to_s
    sentences.join
  end

  private

  def event_name
    name = @game.title_playoff? ? Game::TITLE_PLAYOFF : @game.playoff.presence || "第#{@game.game_number}回戦"
    "東京六大学野球 #{@game.season.title}リーグ戦 #{name}"
  end

  def teams_label
    "#{@game.team0.short_name}対#{@game.team1.short_name}"
  end

  def date_label
    date = @game.played_on
    "#{date.year}年#{date.month}月#{date.day}日（#{WEEKDAYS[date.wday]}）"
  end

  def stadium
    @scoreboard.stadium.to_s.strip.presence
  end

  # 「2026年9月27日（日）、神宮球場で行われた東京六大学野球 2026年秋季リーグ戦 第1回戦は、
  # 慶大が立大に4-2で勝った。」
  def result
    place = stadium ? "#{stadium}で行われた" : ""
    head = "#{date_label}、#{place}#{event_name}は、"

    winner, loser, winner_score, loser_score = sides
    return "#{head}#{@game.team0.short_name}と#{@game.team1.short_name}が#{@game.team0_score}-#{@game.team1_score}で引き分けた。" unless winner

    extra = extra_innings ? "延長#{extra_innings}回の末、" : ""
    verb = walk_off? ? "サヨナラ勝ちした" : "勝った"
    "#{head}#{winner.short_name}が#{extra}#{loser.short_name}に#{winner_score}-#{loser_score}で#{verb}。"
  end

  # [winner, loser, winner's score, loser's score], or nils for a draw.
  def sides
    if @game.team0_score > @game.team1_score
      [ @game.team0, @game.team1, @game.team0_score, @game.team1_score ]
    elsif @game.team1_score > @game.team0_score
      [ @game.team1, @game.team0, @game.team1_score, @game.team0_score ]
    else
      [ nil, nil, nil, nil ]
    end
  end

  # The last inning, when past the ninth.
  def extra_innings
    last = @scoreboard.innings.to_a.last
    last if last && last > 9
  end

  # The home side (team1, batting second) won, and its last half-inning is
  # marked as ended before three outs: Scorebook writes the runs as "2x".
  def walk_off?
    last = @scoreboard.innings.to_a.last or return false
    @game.team1_score > @game.team0_score && @scoreboard.bottom_runs(last).to_s.match?(/\A\d+x\z/i)
  end

  def pitchers
    winning = pitching_lines.find { |line| line.wins.to_i.positive? }
    losing = pitching_lines.find { |line| line.losses.to_i.positive? }
    parts = [ ("勝利投手は#{player_label(winning)}" if winning), ("敗戦投手は#{player_label(losing)}" if losing) ].compact
    "#{parts.join('、')}。" if parts.any?
  end

  # 「本塁打は井上 和輝（法大）、片山 悠真（法大）2本。」
  def home_runs
    hitters = batting_lines.select { |line| line.home_runs.to_i.positive? }
    return nil if hitters.empty?

    "本塁打は#{hitters.map { |line| "#{player_label(line)}#{"#{line.home_runs}本" if line.home_runs > 1}" }.join('、')}。"
  end

  def crowd_and_time
    parts = []
    parts << "観衆は#{attendance.to_fs(:delimited)}人" if attendance
    parts << "試合時間は#{@scoreboard.duration_minutes / 60}時間#{@scoreboard.duration_minutes % 60}分" if @scoreboard.duration_minutes
    weather = [ @game.weather_summary.presence, ("最高気温#{@game.temp_high}℃" if @game.temp_high.present?) ].compact
    parts << "東京の天気は#{weather.join('、')}" if weather.any?
    "#{parts.join('、')}。" if parts.any?
  end

  def attendance
    @game.attendance || @scoreboard.attendance.to_s.delete(",").strip.presence&.to_i
  end

  # 「これでこのカードは慶大の2勝1敗。」: the card's held games up to this one,
  # counted from the side ahead (or level). Not for a playoff, which is no card.
  def card_standing
    return nil unless @game.counted_in_stats

    games = Game.held.where(season_id: @game.season_id, counted_in_stats: true)
      .where(team0_id: [ @game.team0_id, @game.team1_id ], team1_id: [ @game.team0_id, @game.team1_id ])
      .where("played_on <= ?", @game.played_on).to_a.select(&:decided?)
    wins = ->(team) { games.count { |game| (game.team0_id == team.id ? game.team0_score - game.team1_score : game.team1_score - game.team0_score).positive? } }
    draws = games.count { |game| game.team0_score == game.team1_score }
    leader, other = [ @game.team0, @game.team1 ].sort_by { |team| -wins.(team) }
    record = "#{wins.(leader)}勝#{wins.(other)}敗#{"#{draws}分" if draws.positive?}"

    if wins.(leader).zero?
      "これでこのカードは#{draws}引き分け。"
    elsif wins.(leader) == wins.(other)
      "これでこのカードは#{record}の五分。"
    elsif wins.(leader) == 2 && sides.first == leader && @game.season.ranked?
      "これでこのカードは#{leader.short_name}の#{record}となり、#{leader.short_name}が勝ち点を得た（今季の勝ち点#{points_so_far(leader)}）。"
    else
      "これでこのカードは#{leader.short_name}の#{record}。"
    end
  end

  # The 勝ち点 university has won in the season up to this game's day.
  def points_so_far(university)
    games = Game.held.where(season_id: @game.season_id, counted_in_stats: true).where("played_on <= ?", @game.played_on).to_a
    Standings.new(@game.season, games: games).row_for(university).points
  end

  # 「立大にとってこのシーズン唯一の負けとなった。」 (or 唯一の勝利): only once the
  # season is over, and only for one Scorebook has (a season taken from a
  # printed source has only the games of one university).
  def only_win_or_loss
    winner, loser = sides
    return nil unless winner && @game.counted_in_stats
    return nil unless @game.season.scorebook_games.present? && @game.season.finished?

    games = Game.held.where(season_id: @game.season_id, counted_in_stats: true).to_a.select(&:decided?)
    results = ->(team, won) { games.select { |game| [ game.team0_id, game.team1_id ].include?(team.id) && (game.team0_score != game.team1_score) && ((game.team0_score > game.team1_score ? game.team0_id : game.team1_id) == team.id) == won } }
    parts = []
    parts << "#{loser.short_name}にとってこのシーズン唯一の負け" if results.(loser, false) == [ @game ]
    parts << "#{winner.short_name}にとってこのシーズン唯一の勝利" if results.(winner, true) == [ @game ]
    "#{parts.join('、')}となった。" if parts.any?
  end

  # 「残りの試合の勝敗を五分とした優勝確率は、明大が54%から66%に上がり、法大が12%から5%に下がった。」
  # or 「これで明大の優勝が決まった。」 (ChampionshipOdds), as for a playoff won.
  # Left out when they aren't worked out (the first half of a season), when the
  # title was already decided, and when the game moved neither side's chance.
  def title_race
    return title_decided(sides.first) if @game.title_playoff? && sides.first

    odds = ChampionshipOdds.around(@game) or return nil
    before, after = odds.values_at(:before, :after)

    champion = after.find { |_, chance| chance >= 1 }&.first
    if champion
      return nil if before[champion] >= 1

      return title_decided(University.find(champion))
    end

    winner, loser = sides
    changes = (winner ? [ winner, loser ] : [ @game.team0, @game.team1 ]).filter_map do |team|
      from, to = before[team.id], after[team.id]
      next if percent_label(from) == percent_label(to)

      if to.zero?
        [ "#{team.short_name}が#{percent_label(from)}から0%になって優勝の可能性がなくな", "り", "った" ]
      else
        [ "#{team.short_name}が#{percent_label(from)}から#{percent_label(to)}に#{to > from ? "上が" : "下が"}", "り", "った" ]
      end
    end
    return nil if changes.empty?

    # Every clause but the last ends 「〜り、」, the last 「〜った。」.
    clauses = changes.each_with_index.map { |(stem, cont, last), i| stem + (i == changes.size - 1 ? last : cont) }
    "残りの試合の勝敗を五分とした優勝確率は、#{clauses.join('、')}。"
  end

  # 「これで明大の優勝が決まった。」, or 「これで明大の3シーズン連続の優勝が決まった。」
  # when it won the seasons just before (SeasonChampion).
  def title_decided(champion)
    streak = SeasonChampion.streak(@game.season, champion)
    "これで#{champion.short_name}の#{"#{streak}シーズン連続の" if streak > 1}優勝が決まった。"
  end

  # The runs of seasons in a row (StreakRecords) this game settled: at stake
  # after the game before it, decided or ended after this one. 「これで明大の10季
  # 連続の2位以上が決まった（1989年春の法大以来）。」, 「これで明大は立大から10季連続で
  # 勝ち点を取った。」, 「これで早大の連続Aクラスは5季で途切れた。」 A title decided is
  # told by title_race, with its run.
  def streaks
    return nil unless @game.counted_in_stats

    games = TitleRace.games_of(@game.season).select(&:decided?).sort_by { |game| TitleRace.order_key(game) }
    index = games.index { |game| game.id == @game.id }
    return nil if index.nil? || index.zero?

    key = ->(record) { [ record.university.id, record.kind.key, record.opponent&.id ] }
    before = StreakRecords.new(@game.season, after: games[index - 1])
    return nil unless before.applicable?

    after = StreakRecords.new(@game.season, after: @game)
    # Before the places were counted, a run only looked at stake: it may have been
    # settled games ago. Only a card's run is then told, its card won or lost here.
    counted = before.counted?
    at_stake = before.records.select { |record| record.status == :at_stake && (counted || record.kind.key == :card) }.map(&key).to_set
    settled = after.records.select do |record|
      record.status != :at_stake && at_stake.include?(key.(record)) && !(record.kind.key == :champion && record.status == :decided)
    end

    # A comeback is at stake only once counted (a card's from its first game), so
    # one decided here was at stake just before.
    coming = before.comebacks.select { |comeback| comeback.status == :at_stake }.map(&key).to_set
    back = after.comebacks.select { |comeback| comeback.status == :decided && coming.include?(key.(comeback)) }

    (settled.map { |record| streak_sentence(record) } + back.map { |comeback| comeback_sentence(comeback) }).join.presence
  end

  # 「これで東大の1981年春以来、92季ぶりのAクラスが決まった。」; the title's, after the
  # sentence that it was decided, 「立大の優勝は1990年秋以来、53季ぶり。」
  def comeback_sentence(comeback)
    university = comeback.university.short_name
    since = comeback.count ? "#{comeback.last[0]}年#{comeback.last[1] == 1 ? "春" : "秋"}以来、#{comeback.count}季ぶり" : "1950年以降初"
    case comeback.kind.key
    when :champion then "#{university}の優勝は#{since}。"
    when :card
      "これで#{university}は#{comeback.opponent.short_name}から#{comeback.count ? "#{since}に" : "1950年以降初めて"}勝ち点を取った。"
    else "これで#{university}の#{since}の#{COMEBACK_NAMES.fetch(comeback.kind.key)}が決まった。"
    end
  end

  STREAK_NAMES = { champion: "優勝", top_two: "2位以上", a_class: "Aクラス", winning: "勝ち越し", last: "最下位" }.freeze
  COMEBACK_NAMES = STREAK_NAMES.except(:last).merge(b_class: "Bクラス", off_bottom: "最下位脱出").freeze

  def streak_sentence(record)
    university = record.university.short_name
    if record.status == :ended
      run = record.kind.key == :card ? "#{record.opponent.short_name}からの連続勝ち点" : "連続#{STREAK_NAMES.fetch(record.kind.key)}"
      return "これで#{university}の#{run}は#{record.count}季で途切れた。"
    end

    since, holder, opponent = record.since
    note = if since
      "（#{since.to[0]}年#{since.to[1] == 1 ? "春" : "秋"}の#{holder.short_name}#{"の対#{opponent.short_name}" if opponent}以来）"
    elsif record.rank == 1
      "（1950年以降で最長）"
    end
    if record.kind.key == :card
      "これで#{university}は#{record.opponent.short_name}から#{record.count}季連続で勝ち点を取った#{note}。"
    else
      "これで#{university}の#{record.count}季連続の#{STREAK_NAMES.fetch(record.kind.key)}が決まった#{note}。"
    end
  end

  def percent_label(chance)
    if chance.zero? then "0%"
    elsif chance >= 1 then "100%"
    elsif chance < 0.005 then "1%未満"
    elsif chance >= 0.995 then "99%超"
    else "#{(chance * 100).round}%"
    end
  end

  def pitching_lines
    @pitching_lines ||= @game.pitching_lines.includes(:player, :university).to_a
  end

  def batting_lines
    @batting_lines ||= @game.batting_lines.includes(:player, :university).order(:id).to_a
  end

  def player_label(line)
    "#{line.player.name}（#{line.university.short_name}）"
  end
end

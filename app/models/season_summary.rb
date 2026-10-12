# A season told in a sentence or two (シーズンの要約), at the top of its page and
# as its description: who won it and how (勝ち点 and record, a 完全優勝 of all
# five cards, or a playoff), or while it is on, who leads after how many games.
#
# Like GameSummary, for people and for search engines and AI search alike. The
# champion is taken from the standings (勝ち点, then 勝率), or from the playoff
# when there was one; but only for seasons played under that system, so no
# champion is claimed for 2020 and 2021 (a one-game round, then two-game cards
# scored in points, which the standings here don't follow) or for the seasons
# before 1950, whose formats varied. For those it says only what the page lists.
class SeasonSummary
  POINTS_SEASONS = [ [ 2020, "spring" ], [ 2020, "autumn" ], [ 2021, "spring" ], [ 2021, "autumn" ] ].freeze
  FIRST_YEAR_RANKED = 1950

  def initialize(season, standings, games)
    @season = season
    @standings = standings
    @games = games
  end

  def to_s
    "東京六大学野球 #{@season.title}リーグ戦は、#{body}"
  end

  private

  def body
    held = @games.reject(&:not_held?)
    decided = held.select(&:decided?)
    return "試合の記録がない。" if @games.empty? && @season.year < Date.current.year
    return "まだ試合が行われていない。" if decided.empty?
    return "全#{held.size}試合が行われた。" unless ranked?

    @season.finished? ? champion : "#{last_date(decided)}までに#{decided.size}試合を終え、#{leaders}。"
  end

  def ranked?
    @season.year >= FIRST_YEAR_RANKED && !POINTS_SEASONS.include?([ @season.year, @season.term ])
  end

  # 「明大が勝ち点5（10勝0敗）で完全優勝した。」, or the playoff's winner.
  def champion
    playoff = @games.find { |game| !game.counted_in_stats && game.decided? && game.team0_score != game.team1_score }
    if playoff
      winner, loser = playoff.team0_score > playoff.team1_score ? [ playoff.team0, playoff.team1 ] : [ playoff.team1, playoff.team0 ]
      tied = @standings.rows.first.points
      return "#{winner.short_name}と#{loser.short_name}が勝ち点#{tied}で並び、優勝決定戦で#{winner.short_name}が#{[ playoff.team0_score, playoff.team1_score ].max}-#{[ playoff.team0_score, playoff.team1_score ].min}で勝って優勝した。"
    end

    top = @standings.rows.first
    record = "勝ち点#{top.points}（#{top.wins}勝#{top.losses}敗#{"#{top.draws}分" if top.draws.positive?}）"
    top.points == 5 ? "#{top.university.short_name}が#{record}で完全優勝した。" : "#{top.university.short_name}が#{record}で優勝した。"
  end

  # 「慶大が勝ち点3（6勝1敗）で首位」, or the universities level at the top.
  def leaders
    key = ->(row) { [ row.points, row.percentage.round(6) ] }
    top = @standings.rows.select { |row| key.(row) == key.(@standings.rows.first) }
    first = top.first
    if top.size == 1
      "#{first.university.short_name}が勝ち点#{first.points}（#{first.wins}勝#{first.losses}敗#{"#{first.draws}分" if first.draws.positive?}）で首位"
    else
      "#{top.map { |row| row.university.short_name }.join('と')}が勝ち点#{first.points}で首位に並ぶ"
    end
  end

  def last_date(games)
    date = games.map(&:played_on).max
    "#{date.month}月#{date.day}日"
  end
end

# 第57回明治神宮野球大会（2026年11月19日〜24日）の日取り, for the article at
# /articles/jingu-tournament-2026 and its calendar (.ics): every game of the
# 高校の部 and the 大学の部 as 日本学生野球協会's schedule gave it on 2026-11-15
# (https://www.student-baseball.or.jp/system/prog/schedule.php?m=pc&k=all&e=jingu&s=2026),
# a side not yet decided as nil, and the 大学の部's bracket (bracket.php there),
# which says whose winner fills each blank. 明治大 is the 東京六大学's
# representative (2026年秋季の優勝校).
#
# The schedule gives only start times; the calendar has each game end two and a
# half hours on (a guess, as the article says), but no later than the next game's start.
class JinguTournament2026
  SOURCE_URL = "https://www.student-baseball.or.jp/system/prog/schedule.php?m=pc&k=all&e=jingu&s=2026".freeze
  BRACKET_URL = "https://www.student-baseball.or.jp/system/prog/bracket.php?m=pc&e=jingu&s=2026&d=college&k=all".freeze
  DIVISIONS = { "highschool" => "高校", "college" => "大学" }.freeze
  GAME_LENGTH = 150 # minutes

  # A game: its day, division, number on the day (第1試合…), start, round, and sides (nil: not yet decided).
  Game = Data.define(:date, :division, :number, :start, :round, :team0, :team1) do
    def division_label = DIVISIONS.fetch(division)

    def college? = division == "college"

    # 「仙台育英高 vs 鹿児島城西高」, 「明治大 vs 未定」.
    def matchup = [ team0, team1 ].map { |team| team || "未定" }.join(" vs ")
  end

  GAMES = [
    [ "2026-11-19", "highschool", 1, "8:30", "1回戦", "仙台育英高", "鹿児島城西高" ],
    [ "2026-11-19", "highschool", 2, "11:00", "1回戦", "創志学園高", "北海高" ],
    [ "2026-11-19", "college", 3, "13:30", "1回戦", "筑波大", "中京大" ],
    [ "2026-11-19", "college", 4, "16:00", "1回戦", "環太平洋大", "神戸医療未来大" ],
    [ "2026-11-20", "highschool", 1, "8:30", "2回戦", "二松学舎大高", "明徳義塾高" ],
    [ "2026-11-20", "highschool", 2, "11:00", "2回戦", "帝京長岡高", "常葉菊川高" ],
    [ "2026-11-20", "college", 3, "13:30", "1回戦", "九州共立大", "日本体育大" ],
    [ "2026-11-20", "college", 4, "16:00", "2回戦", "大阪商業大", "東農大オホーツク" ],
    [ "2026-11-21", "highschool", 1, "8:30", "2回戦", "横浜高", nil ],
    [ "2026-11-21", "highschool", 2, "11:00", "2回戦", nil, "京都国際高" ],
    [ "2026-11-21", "college", 3, "13:30", "2回戦", "明治大", nil ],
    [ "2026-11-21", "college", 4, "16:00", "2回戦", nil, "仙台大" ],
    [ "2026-11-22", "highschool", 1, "10:00", "準決勝", nil, nil ],
    [ "2026-11-22", "highschool", 2, "12:30", "準決勝", nil, nil ],
    [ "2026-11-22", "college", 3, "15:00", "2回戦", "亜細亜大", nil ],
    [ "2026-11-23", "college", 1, "10:00", "準決勝", nil, nil ],
    [ "2026-11-23", "college", 2, "12:30", "準決勝", nil, nil ],
    [ "2026-11-24", "highschool", 1, "10:00", "決勝", nil, nil ],
    [ "2026-11-24", "college", 2, "13:00", "決勝", nil, nil ]
  ].map do |date, division, number, start, round, team0, team1|
    Game.new(date: Date.parse(date), division:, number:, start: start.split(":").map(&:to_i), round:, team0:, team1:)
  end.freeze

  # Who fills the 大学の部's blanks (the bracket), by the game's day and number.
  COLLEGE_BLANKS = {
    [ Date.new(2026, 11, 21), 3 ] => "筑波大–中京大の勝者",
    [ Date.new(2026, 11, 21), 4 ] => "環太平洋大–神戸医療未来大の勝者",
    [ Date.new(2026, 11, 22), 3 ] => "九州共立大–日本体育大の勝者",
    [ Date.new(2026, 11, 23), 1 ] => "大阪商業大–東農大オホーツクの勝者 vs 明治大の2回戦の勝者",
    [ Date.new(2026, 11, 23), 2 ] => "仙台大の2回戦の勝者 vs 亜細亜大の2回戦の勝者",
    [ Date.new(2026, 11, 24), 2 ] => "準決勝の勝者どうし"
  }.freeze

  # The 大学の部's bracket as a tree: a match is its game (by day and number on the
  # day, as in GAMES) and its two sides, each a university or the match it is the
  # winner of. In the bracket page's order, top to bottom.
  Match = Data.define(:date, :number, :sides) do
    def game = GAMES.find { |game| game.date == date && game.number == number }

    def universities = sides.flat_map { |side| side.is_a?(Match) ? side.universities : [ side ] }

    def include?(university) = universities.include?(university)
  end

  match = ->(day, number, *sides) { Match.new(date: Date.new(2026, 11, day), number:, sides:) }
  COLLEGE_BRACKET = match.(24, 2,
    match.(23, 1,
      match.(20, 4, "大阪商業大", "東農大オホーツク"),
      match.(21, 3, "明治大", match.(19, 3, "筑波大", "中京大"))),
    match.(23, 2,
      match.(21, 4, match.(19, 4, "環太平洋大", "神戸医療未来大"), "仙台大"),
      match.(22, 3, "亜細亜大", match.(20, 3, "九州共立大", "日本体育大"))))

  # 明治大's matches if it wins them all, first to last, each with the universities
  # it could meet there (those on the other side).
  def self.meiji_path(node = COLLEGE_BRACKET)
    return [] unless node.is_a?(Match) && node.include?("明治大")

    own, other = node.sides.partition { |side| side == "明治大" || (side.is_a?(Match) && side.include?("明治大")) }.map(&:first)
    opponents = other.is_a?(Match) ? other.universities : [ other ]
    meiji_path(own) + [ [ node, opponents ] ]
  end

  # division: "college" or "highschool" for one division's games, or "meiji" for
  # 明治大's games if it wins them all; nil for all.
  def initialize(division: nil)
    @division = (DIVISIONS.keys + [ "meiji" ]).include?(division) ? division : nil
  end

  def games
    case @division
    when nil then GAMES
    when "meiji" then self.class.meiji_path.map { |match, _| match.game }
    else GAMES.select { |game| game.division == @division }
    end
  end

  # 「8:30 am」「1:30 pm」.
  def self.time_label((hour, minute))
    "#{(hour - 1) % 12 + 1}:#{format("%02d", minute)} #{hour < 12 ? "am" : "pm"}"
  end

  def self.blank_note(game)
    COLLEGE_BLANKS[[ game.date, game.number ]] if game.college?
  end

  def to_ics
    tokyo = ActiveSupport::TimeZone["Asia/Tokyo"]
    name = { nil => "", "meiji" => "（明治大が勝ち進んだ場合）" }.fetch(@division) { "（#{DIVISIONS[@division]}の部）" }
    calendar = IcsCalendar.new(name: "2026年 明治神宮野球大会#{name}")
    # In 明治大's calendar, its side of each game, and who it could meet there.
    meiji = (self.class.meiji_path.to_h { |match, opponents| [ match.game, opponents ] } if @division == "meiji")
    games.each do |game|
      start = tokyo.local(game.date.year, game.date.month, game.date.day, *game.start)
      following = GAMES.find { |other| other.date == game.date && other.number == game.number + 1 }
      finish = [ start + GAME_LENGTH.minutes, following && tokyo.local(game.date.year, game.date.month, game.date.day, *following.start) ].compact.min
      calendar.add_event(
        uid: "jingu-2026-#{game.date.strftime("%m%d")}-#{game.number}@big6",
        summary: "【神宮大会・#{game.division_label}】#{meiji ? "明治大 vs 未定" : game.matchup}（#{game.round}）",
        start_time: start, end_time: finish,
        location: StadiumLocation.for("神宮球場"),
        description: [ "第57回明治神宮野球大会 #{game.division_label}の部 #{game.round} 第#{game.number}試合。",
          meiji ? "明治大が勝ち進んだ場合。相手は#{meiji.fetch(game).join("・")}のどれか。" : self.class.blank_note(game),
          "日本学生野球協会の日程（2026年11月15日時点）より。終了時刻は目安。" ].compact.join(" ")
      )
    end
    calendar.to_ics
  end
end

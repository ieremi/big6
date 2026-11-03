module SeasonsHelper
  # The sortable columns of the standings table: heading => [shortcut, direction of
  # the first click, the cell-toggle group it belongs to (shown with the results or
  # with the attendance)]. Counts start with the most, except the losses and the
  # runs allowed, which start with the fewest (the better first, as the rank does).
  # The columns of the results against each opponent aren't sortable.
  STANDINGS_COLUMNS = {
    "試合" => [ "G", "desc", "resultsColumn" ], "勝利" => [ "W", "desc", "resultsColumn" ], "敗戦" => [ "L", "asc", "resultsColumn" ],
    "引分" => [ "D", "desc", "resultsColumn" ], "勝ち点" => [ "P", "desc", "resultsColumn" ], "勝率" => [ "A", "desc", "resultsColumn" ],
    "得点" => [ "S", "desc", "resultsColumn" ], "失点" => [ "E", "asc", "resultsColumn" ],
    "総観衆" => [ "T", "desc", "attendanceColumn" ], "平均観衆" => [ "V", "desc", "attendanceColumn" ]
  }.freeze

  # The headings of those columns, in order. The attendance's start hidden, as the
  # table first shows the results (cell-toggle switches them once it starts).
  def standings_stat_headers
    safe_join(STANDINGS_COLUMNS.map do |label, (shortcut, first, group)|
      sortable_column_header(label, shortcut, first: first, hidden: group == "attendanceColumn", data: { cell_toggle_target: group })
    end)
  end

  # The チーム成績 table's columns (TeamStats): [shortcut, first direction]. The
  # shortcuts are other letters than the standings table's on the same page.
  TEAM_STATS_COLUMNS = {
    "試合" => [ "N", "desc" ], "打率" => [ "B", "desc" ], "本塁打" => [ "H", "desc" ], "盗塁" => [ "R", "desc" ],
    "防御率" => [ "Q", "asc" ], "失策" => [ "F", "asc" ]
  }.freeze

  # The mark of a convention's result (ScheduleConventions) and what it means.
  CONVENTION_MARKS = {
    followed: [ "○", "したがっている" ], broken: [ "×", "したがっていない" ],
    unknown: [ "？", "前季に同順位があって判定できない" ], nil => [ "−", "条件にあてはまらない" ]
  }.freeze

  def conventions_mark(outcome)
    CONVENTION_MARKS.fetch(outcome)
  end

  # A strength (TeamStrength's chance of beating an average side) in each of the
  # three ways the strength charts show it (seasons/_strength_views), for text and
  # tables inside the same view-switch: 「59%」, odds 「1.44」, log odds 「+0.36」,
  # the chance's shown and the others hidden until their button is pressed.
  def strength_figure(chance)
    odds = chance / (1 - chance)
    logit = Math.log(odds)
    safe_join([
      tag.span("#{(chance * 100).round}%", data: { view_switch_target: "panel", view: "chance" }),
      tag.span(format("%.2f", odds), hidden: true, data: { view_switch_target: "panel", view: "odds" }),
      tag.span(logit.round(2).zero? ? "0.00" : format("%+.2f", logit), hidden: true, data: { view_switch_target: "panel", view: "logit" })
    ])
  end

  # 「2022年春」 for a StreakRecords season key ([2022, 1]).
  def streak_season_label(key)
    "#{key[0]}年#{key[1] == 1 ? "春" : "秋"}"
  end

  # What a StreakRecords record says, after the university's name: 「2位以上　10季連続
  # （2022年春〜）」, 「今季も続けば10季連続」, or 「9季連続で途切れた（2022年春〜2026年春）」.
  def streak_record_text(record)
    span = "#{streak_season_label(record.from)}〜#{streak_season_label(record.to) if record.status == :ended}"
    case record.status
    when :decided then "#{record.label}　#{record.count}季連続（#{span}）"
    when :at_stake then "#{record.label}　今季も続けば#{record.count}季連続（#{span}）"
    when :ended then "#{record.label}　#{record.count}季連続で途切れた（#{span}）"
    end
  end

  # How a decided or at-stake run stands: 「歴代2位タイ。1989年春の法大（18季）以来。明大で最長」.
  def streak_record_notes(record)
    return "" if record.status == :ended

    who = record.opponent ? "#{record.university.short_name}の対#{record.opponent.short_name}" : record.university.short_name
    since, holder, since_opponent = record.since
    longest, longest_holder, longest_opponent = record.longest
    [
      "1950年以降で歴代#{record.rank}位#{"タイ" if record.tied}",
      ("#{streak_season_label(since.to)}の#{holder.short_name}（#{"対#{since_opponent.short_name}" if since_opponent}#{since.count}季）以来" if since),
      ("#{who}で最長" if record.own_best),
      ("最長は#{longest_holder.short_name}の#{"対#{longest_opponent.short_name}" if longest_opponent}#{longest.count}季（#{streak_season_label(longest.from)}〜#{streak_season_label(longest.to)}）" if longest)
    ].compact.join("。") + "。"
  end

  # What a StreakRecords comeback says, after the university's name: 「Aクラス（3位以上）
  # 92季ぶり（前回1981年春）」, or 「優勝　1950年以降初」.
  def comeback_text(comeback)
    return "#{comeback.label}　1950年以降初" unless comeback.count

    "#{comeback.label}　#{comeback.count}季ぶり（前回#{streak_season_label(comeback.last)}）"
  end

  # How the gap stands: 「1950年以降で歴代2位。1993年秋の東大（法大から81季ぶり）以来」.
  # The rank only in the top ten, as short gaps are many.
  def comeback_notes(comeback)
    return "" unless comeback.count

    gap = ->((run, holder, opponent)) { "#{streak_season_label(run.to)}の#{holder.short_name}（#{"#{opponent.short_name}から" if opponent}#{run.count}季ぶり）" }
    [
      ("1950年以降で歴代#{comeback.rank}位#{"タイ" if comeback.tied}" if comeback.rank <= 10),
      ("#{gap.(comeback.since)}以来" if comeback.since),
      ("最長は#{gap.(comeback.longest)}" if comeback.longest)
    ].compact.join("。").then { |text| text.empty? ? text : "#{text}。" }
  end

  # Text with strengths written in it as {59} (a chance in percent): each one
  # shown as strength_figure, so the text follows the buttons too.
  def with_strength_figures(text)
    safe_join(text.split(/\{(\d+(?:\.\d+)?)\}/).each_with_index.map { |part, index| index.odd? ? strength_figure(part.to_f / 100) : part })
  end
end

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

  # Text with strengths written in it as {59} (a chance in percent): each one
  # shown as strength_figure, so the text follows the buttons too.
  def with_strength_figures(text)
    safe_join(text.split(/\{(\d+(?:\.\d+)?)\}/).each_with_index.map { |part, index| index.odd? ? strength_figure(part.to_f / 100) : part })
  end
end

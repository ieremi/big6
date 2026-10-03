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

  # The headings of those columns, in order.
  def standings_stat_headers
    safe_join(STANDINGS_COLUMNS.map do |label, (shortcut, first, group)|
      sortable_column_header(label, shortcut, first: first, data: { cell_toggle_target: group })
    end)
  end
end

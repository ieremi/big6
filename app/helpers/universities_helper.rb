module UniversitiesHelper
  # The columns of the games table on a university page: heading => [shortcut,
  # direction of the first click]. None of them is a key the roster table on the
  # same page uses.
  GAME_COLUMNS = {
    "日付" => [ "D", "asc" ], "回戦" => [ "G", "asc" ], "相手" => [ "V", "asc" ],
    "結果" => [ "W", "asc" ], "観衆" => [ "A", "desc" ]
  }.freeze

  RESULT_ORDER = %w[勝 敗 分].freeze

  # "勝", "敗" or "分" for the university in a game that is over; nil for one
  # that isn't (still to come, under way, or not held).
  def game_result_for(game, university)
    return nil unless game.decided?

    own, other = game.team0_id == university.id ? [ game.team0_score, game.team1_score ] : [ game.team1_score, game.team0_score ]
    own > other ? "勝" : (own < other ? "敗" : "分")
  end

  def game_opponent(game, university)
    game.team0_id == university.id ? game.team1 : game.team0
  end
end

module Admin
  module SuggestionsHelper
    KIND_LABELS = {
      "misfiled_lines" => "別の試合に登録された成績",
      "same_team_game" => "両チームが同じ大学の試合"
    }.freeze

    STATUS_LABELS = { "pending" => "未決定", "not_needed" => "対応不要", "approved" => "承認", "discarded" => "却下" }.freeze

    CONFIDENCE_LABELS = { "likely" => "候補1つ", "needs_review" => "要確認" }.freeze

    # The batting columns shown for each line, in the order of a box score.
    LINE_COLUMNS = {
      "pa" => "打席", "ab" => "打数", "hits" => "安打", "doubles" => "二塁打", "triples" => "三塁打", "home_runs" => "本塁打",
      "rbi" => "打点", "runs" => "得点", "walks" => "四死球", "strikeouts" => "三振", "stolen_bases" => "盗塁"
    }.freeze

    # Every batting column's name, for the differences between Scorebook and us.
    FIELD_LABELS = LINE_COLUMNS.merge(
      "sacrifices" => "犠打・犠飛", "caught_stealing" => "盗塁死", "gidp" => "併殺打", "fielding_errors" => "失策"
    ).freeze

    # A line's FixSuggestion::LineState in words: "取り込み済み（差あり：安打 Scorebook 1 / 当サイト 0）".
    def fix_suggestion_line_state_label(state)
      case state.state
      when :no_game then "—"
      when :to_apply then "未反映"
      when :stray then "反映しない（同じ日に正しい試合 #{state.line.twin_scorebook_game_id} の行あり）"
      when :applied then "反映済み"
      when :imported_match then "取り込み済み（一致）"
      when :imported_differs
        details = state.differences.map { |field, scorebook, ours| "#{FIELD_LABELS.fetch(field.to_s, field.to_s)} Scorebook #{scorebook} / 当サイト #{ours}" }
        "取り込み済み（差あり：#{details.join("、")}）"
      end
    end

    # The kind in words; one whose lines have all strayed in from another game
    # (FixSuggestion#stray?) is told apart.
    def fix_suggestion_kind_label(suggestion)
      return "別の試合の成績の紛れ込み（要確認）" if suggestion.stray?

      KIND_LABELS.fetch(suggestion.kind, suggestion.kind)
    end

    def fix_suggestion_status_label(status)
      STATUS_LABELS.fetch(status, status)
    end

    def fix_suggestion_confidence_label(confidence)
      CONFIDENCE_LABELS.fetch(confidence, confidence)
    end

    # "2025-10-05 法大の成績（東大 vs 慶大 に登録）"
    def fix_suggestion_title(suggestion)
      filed = suggestion.filed_under_game
      where = filed ? "#{filed.team0.short_name} vs #{filed.team1.short_name}" : "試合ID #{suggestion.scorebook_game_id}"
      "#{suggestion.played_on} #{suggestion.university&.short_name}の成績（#{where} に登録）"
    end

    # A game of ours as "2025-10-05 早大 vs 法大 2回戦", linked to its page when it has one.
    def fix_suggestion_game_link(game)
      return "なし" unless game

      label = "#{game.played_on} #{game.team0.short_name} vs #{game.team1.short_name} #{round_label(game)}"
      game.game_number ? link_to(label, game_path(game)) : label
    end

    def scorebook_game_page_url(scorebook_game_id)
      FixSuggestion.scorebook_game_url(scorebook_game_id)
    end

    def scorebook_member_page_url(player)
      "https://big6scorebook.jp/member/#{player.scorebook_id}"
    end

    # "✓ 11 / 11" when the lines' hits make the team's hits on the scoreboard.
    def fix_suggestion_hits_label(check)
      return "—" unless check
      return "#{check[:lines]} / 不明" if check[:scoreboard].nil?

      "#{check[:lines] == check[:scoreboard] ? "✓" : "…"} #{check[:lines]} / #{check[:scoreboard]}"
    end
  end
end

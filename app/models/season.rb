class Season < ApplicationRecord
    has_many :games

    TERM_LABELS = { "spring" => "春季", "autumn" => "秋季" }.freeze

    def term_ja
        TERM_LABELS.fetch(term, term)
    end

    def title
        "#{year}年#{term_ja}"
    end

    def finished?
        return true if scorebook_games.blank?

        scorebook_games.none? { |g| g["gameStatus"] == "試合前" }
    end

    # O(1) after the first call per season (memoized), instead of every
    # caller doing its own O(n) Array#find over the season's full cached
    # box-score list — this is on a hot path (called per game on pages that
    # render many games at once, like the all-games ICS export).
    def scorebook_game(scorebook_game_id)
        return nil if scorebook_game_id.nil?

        @scorebook_games_by_id ||= (scorebook_games || []).index_by { |g| g["id"] }
        @scorebook_games_by_id[scorebook_game_id]
    end
end

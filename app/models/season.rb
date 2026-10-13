class Season < ApplicationRecord
    has_many :games

    # Newest season first: within a year autumn comes before spring, which
    # ordering by term (a string) would get the wrong way round.
    scope :newest_first, -> { order(Arel.sql("seasons.year DESC, CASE seasons.term WHEN 'autumn' THEN 1 ELSE 0 END DESC")) }

    TERM_LABELS = { "spring" => "春季", "autumn" => "秋季" }.freeze

    def term_ja
        TERM_LABELS.fetch(term, term)
    end

    def title
        "#{year}年#{term_ja}"
    end

    # Seasons ranked the usual way, by 勝ち点 (best-of-three cards won) and then
    # 勝率: from 1950, the formats before it having varied, but not 2020 and 2021
    # (a one-game round, then two-game cards scored in points, which the
    # standings here don't follow).
    POINTS_SEASONS = [ [ 2020, "spring" ], [ 2020, "autumn" ], [ 2021, "spring" ], [ 2021, "autumn" ] ].freeze
    FIRST_YEAR_RANKED = 1950

    def ranked?
        year >= FIRST_YEAR_RANKED && !POINTS_SEASONS.include?([ year, term ])
    end

    # The season before this one (spring before autumn, the year's autumn before
    # the next spring), without the large Scorebook columns.
    def previous
        year_before, term_before = term == "autumn" ? [ year, "spring" ] : [ year - 1, "autumn" ]
        Season.select(:id, :year, :term).find_by(year: year_before, term: term_before)
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

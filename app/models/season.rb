class Season < ApplicationRecord
    has_many :games

    TERM_LABELS = { "spring" => "春季", "autumn" => "秋季" }.freeze

    def term_ja
        TERM_LABELS.fetch(term, term)
    end

    def title
        "#{year}年#{term_ja}"
    end
end

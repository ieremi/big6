class Game < ApplicationRecord
  belongs_to :season
  belongs_to :team0, class_name: "University"
  belongs_to :team1, class_name: "University"

  has_many :game_members, dependent: :destroy
  has_many :batting_lines, dependent: :destroy
  has_many :pitching_lines, dependent: :destroy

  # Games with a final score and a Scorebook id, i.e. ones whose player box
  # score can be fetched.
  scope :with_stats_available, -> { where.not(scorebook_game_id: nil).where.not(team0_score: nil).where.not(team1_score: nil) }

  # Those of them with no player lines imported yet.
  scope :needing_stats, -> { with_stats_available.where.not(id: BattingLine.select(:game_id)) }
end

class Game < ApplicationRecord
  belongs_to :season
  belongs_to :team0, class_name: "University"
  belongs_to :team1, class_name: "University"

  has_many :game_members, dependent: :destroy
  has_many :batting_lines, dependent: :destroy
  has_many :pitching_lines, dependent: :destroy

  # A "中止"/"ノーゲーム" entry is a rained-out (or otherwise voided) attempt,
  # not a game that happened: it has no result, and it is usually replayed
  # later under the same round number. Both Scorebook and the league's own site
  # report these under the same names, which is what game_status holds.
  CANCELLED_STATUSES = %w[中止 ノーゲーム].freeze

  # Scorebook's status for a game that hasn't started.
  PENDING_STATUS = "試合前".freeze

  # Games with a final score and a Scorebook id, i.e. ones whose player box
  # score can be fetched.
  scope :with_stats_available, -> { where.not(scorebook_game_id: nil).where.not(team0_score: nil).where.not(team1_score: nil) }

  # Those of them with no player lines imported yet.
  scope :needing_stats, -> { with_stats_available.where.not(id: BattingLine.select(:game_id)) }

  scope :cancelled, -> { where(game_status: CANCELLED_STATUSES) }
  scope :not_cancelled, -> { where(game_status: nil).or(where.not(game_status: CANCELLED_STATUSES)) }

  # For finding "the game with this round number": a cancelled game and its
  # replay can share one, and the replay is the one that counts.
  scope :cancelled_last, -> { order(Arel.sql(sanitize_sql_array([ "CASE WHEN games.game_status IN (?) THEN 1 ELSE 0 END", CANCELLED_STATUSES ]))) }

  def cancelled?
    CANCELLED_STATUSES.include?(game_status)
  end

  # Records that a game was cancelled, as reported by Scorebook or the league's
  # site: the game gets that status and no result. Returns the game, or nil when
  # we have no such game: a cancelled game we never had isn't added (see
  # CANCELLED_STATUSES: it would only duplicate the round number of its replay).
  #
  # The game is found by its Scorebook id when it has one, else as the game
  # between the two teams (in either order) on that date.
  def self.record_cancellation(season:, team_ids:, played_on:, scorebook_game_id: nil, status: CANCELLED_STATUSES.first)
    game = find_by(season: season, scorebook_game_id: scorebook_game_id) if scorebook_game_id
    game ||= find_by(season: season, played_on: played_on, team0_id: team_ids, team1_id: team_ids)
    return nil unless game

    game.update!(game_status: status, team0_score: nil, team1_score: nil)
    game
  end
end

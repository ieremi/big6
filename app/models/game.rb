class Game < ApplicationRecord
  belongs_to :season
  belongs_to :team0, class_name: "University"
  belongs_to :team1, class_name: "University"

  has_many :game_members, dependent: :destroy
  has_many :batting_lines, dependent: :destroy
  has_many :pitching_lines, dependent: :destroy

  # The state a game is in. The values stored (and shown) are the names Scorebook
  # and the league's site use for them:
  #
  #   scheduled    試合前     not started
  #   in_progress  試合中     under way
  #   finished     試合終了   over, with a result
  #   cancelled    中止       not played (rained out)
  #   no_game      ノーゲーム called off after it began
  #
  # A game that wasn't held (中止 or ノーゲーム) has no result and no round number:
  # it is replayed later, under the number it would have had.
  #
  # game_status reads as the name on the left ("cancelled"); status_label is the
  # Japanese one. Assigning either works.
  enum :game_status, { scheduled: "試合前", in_progress: "試合中", finished: "試合終了", cancelled: "中止", no_game: "ノーゲーム" },
    default: "scheduled", validate: true

  # The two states of a game that wasn't held. Scorebook and the league's site
  # report both under these names, which are the stored values.
  NOT_HELD_STATUSES = %w[中止 ノーゲーム].freeze

  # Scorebook's status for a game that hasn't started.
  PENDING_STATUS = "試合前".freeze

  before_validation :clear_round_of_game_not_held

  validates :game_number, presence: true, unless: :not_held?

  # Games with a final score and a Scorebook id, i.e. ones whose player box
  # score can be fetched.
  scope :with_stats_available, -> { where.not(scorebook_game_id: nil).where.not(team0_score: nil).where.not(team1_score: nil) }

  # Those of them with no player lines imported yet.
  scope :needing_stats, -> { with_stats_available.where.not(id: BattingLine.select(:game_id)) }

  # The games that weren't held (中止 and ノーゲーム), and those that were or are
  # still to be.
  scope :not_held, -> { where(game_status: NOT_HELD_STATUSES) }
  scope :held, -> { where.not(game_status: NOT_HELD_STATUSES) }

  # The status a game gets from what a source reports: the status itself when it is
  # one of ours; otherwise from the score, and the date when there is none.
  def self.status_for(reported, team0_score:, team1_score:, played_on:)
    return reported if game_statuses.value?(reported)
    return "試合終了" if team0_score && team1_score

    played_on >= Date.current ? "試合前" : "試合中"
  end

  # "試合前", "中止", ... for showing.
  def status_label
    self.class.game_statuses.fetch(game_status)
  end

  # Not held (中止 or ノーゲーム): no result to count.
  def not_held?
    cancelled? || no_game?
  end

  def held?
    !not_held?
  end

  # Records that a game was called off, as reported by Scorebook or the league's
  # site: the game gets that status, no result and no round. A game we don't have
  # yet is added, as the game of teams[0] (top) and teams[1] on that date: it has no
  # round number, so it can't take the number of the game that replaces it.
  # attributes are set as well (a Scorebook id and the like).
  #
  # The game is found by its Scorebook id when it has one, else as the game
  # between the two teams (in either order) on that date. With unless_finished, a
  # game Scorebook has as finished is left alone (nil is returned), for when the
  # report may be older than the game's own data.
  def self.record_cancellation(season:, teams:, played_on:, scorebook_game_id: nil, status: NOT_HELD_STATUSES.first, unless_finished: false, attributes: {})
    team_ids = teams.map(&:id)
    game = find_by(season: season, scorebook_game_id: scorebook_game_id) if scorebook_game_id
    game ||= find_by(season: season, played_on: played_on, team0_id: team_ids, team1_id: team_ids)

    if game
      return nil if unless_finished && game.finished?

      game.update!(attributes.merge(scorebook_game_id: scorebook_game_id || game.scorebook_game_id, game_status: status, team0_score: nil, team1_score: nil))
      game
    else
      create!(attributes.merge(season: season, team0: teams[0], team1: teams[1], played_on: played_on, scorebook_game_id: scorebook_game_id, game_status: status))
    end
  end

  private


  def clear_round_of_game_not_held
    self.game_number = nil if not_held?
  end
end

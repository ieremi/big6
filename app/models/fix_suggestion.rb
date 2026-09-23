# A fix to our data, suggested from Scorebook lines the nightly check
# (ScorebookStatsPlayerCheck) finds filed under the wrong game, for an admin to
# approve or discard on the admin pages. Approving only records the decision
# for now; nothing is changed yet.
#
# Two kinds, from a line whose team (a university) isn't one of its game's two
# sides:
#
#   misfiled_lines   the game's sides are two other universities: the line is a
#                    game of the same day's, filed under the wrong game id. Our
#                    game that day for the line's university is where it belongs.
#                    One suggestion per game id and university, gathering the
#                    lines of the whole team as its players are checked.
#   same_team_game   the game's two sides are the same university: Scorebook's
#                    game itself is wrong (its opponent). Only listed, for review.
#
# confidence is "likely" when the guess is the only game it can be, and
# "needs_review" otherwise (several games that day, none, or the second kind).
# The evidence for a guess is worked out when shown (hits_check,
# roster_check, ...), so it grows with the lines gathered.
class FixSuggestion < ApplicationRecord
  KINDS = %w[misfiled_lines same_team_game].freeze
  STATUSES = %w[pending approved discarded].freeze

  belongs_to :university, optional: true
  belongs_to :game, optional: true
  belongs_to :decided_by, class_name: "User", optional: true
  has_many :lines, -> { order(:id) }, class_name: "FixSuggestionLine", dependent: :delete_all

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }

  # Records what the lines of a player's Scorebook member page
  # (ScorebookMemberStats) suggest: each line filed under the wrong game joins
  # the suggestion for it, which is made the first time. A line already
  # recorded is left as it is, and a suggestion already decided (discarded
  # included) is never made again.
  def self.record_from(player, lines)
    lines.each do |line|
      teams = Array(line.game_team_ids)
      next if line.team_id.nil? || line.line_id.nil? || teams.compact.size < 2

      suggestion = if teams.uniq.size == 1
        same_team_game_for(line, player)
      elsif teams.exclude?(line.team_id)
        misfiled_lines_for(line)
      end
      next unless suggestion

      suggestion.lines.find_or_create_by!(scorebook_line_id: line.line_id) do |record|
        record.player = player
        record.position = line.position
        record.values = line.values.transform_keys(&:to_s)
      end
    end
  end

  def self.misfiled_lines_for(line)
    university = university_for(line.team_id) or return nil

    find_or_create_by!(key: "misfiled_lines #{line.scorebook_game_id} #{line.team_id}") do |suggestion|
      candidates = Game.where(played_on: line.played_on).where("team0_id = :id OR team1_id = :id", id: university.id).order(:id).pluck(:id)
      suggestion.kind = "misfiled_lines"
      suggestion.university = university
      suggestion.scorebook_game_id = line.scorebook_game_id
      suggestion.played_on = line.played_on
      suggestion.candidate_game_ids = candidates
      suggestion.game_id = candidates.first if candidates.size == 1
      suggestion.confidence = candidates.size == 1 ? "likely" : "needs_review"
    end
  end

  def self.same_team_game_for(line, player)
    find_or_create_by!(key: "same_team_game #{line.scorebook_game_id}") do |suggestion|
      suggestion.kind = "same_team_game"
      suggestion.university = university_for(line.team_id) || player.university
      suggestion.scorebook_game_id = line.scorebook_game_id
      suggestion.played_on = line.played_on
      suggestion.game = Game.find_by(scorebook_game_id: line.scorebook_game_id)
      suggestion.confidence = "needs_review"
    end
  end

  def self.university_for(scorebook_team_id)
    slug = ScorebookSync::SCOREBOOK_TEAM_SLUGS[scorebook_team_id] or return nil
    University.find_by(slug: slug)
  end

  # The game Scorebook files the lines under, as we have it (nil if we don't).
  def filed_under_game
    Game.find_by(scorebook_game_id: scorebook_game_id)
  end

  def candidate_games
    Game.where(id: candidate_game_ids).includes(:team0, :team1).order(:id)
  end

  # Records an admin's decision: "approved", "discarded", or "pending" to take
  # one back. The note, when given, replaces the one kept.
  def decide!(status, user:, note: nil)
    raise ArgumentError, "unknown decision: #{status.inspect}" unless STATUSES.include?(status)

    decided = status != "pending"
    update!(status: status, decided_by: (user if decided), decided_at: (Time.current if decided), note: note.nil? ? self.note : note.presence)
  end

  # The hits of the lines gathered so far against the team's hits on the
  # guessed game's scoreboard: { lines:, scoreboard: }, scoreboard nil when
  # unknown. When they are equal, the lines are the team's whole box score.
  def hits_check
    return nil unless game && university

    scoreboard = GameScoreboard.new(game)
    team_hits = game.team0_id == university.id ? scoreboard.top_hits : scoreboard.bottom_hits
    { lines: lines.sum { |line| line.value(:hits).to_i }, scoreboard: team_hits&.to_i }
  end

  # How many of the lines' players are on the guessed game's roster for the
  # university (GameMember, 2021 onward): { on_roster:, lines:, roster: }, nil
  # when that game has no roster.
  def roster_check
    return nil unless game && university

    roster_ids = GameMember.where(game: game, university: university).pluck(:player_id)
    return nil if roster_ids.empty?

    { on_roster: lines.count { |line| roster_ids.include?(line.player_id) }, lines: lines.size, roster: roster_ids.size }
  end

  # Whether we already have batting lines for the university in the guessed
  # game (we shouldn't, if they are filed under another game at Scorebook).
  def our_lines_count
    return nil unless game && university

    BattingLine.where(game: game, university: university).count
  end
end

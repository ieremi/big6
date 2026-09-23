# A fix to our data, suggested from Scorebook lines the nightly check
# (ScorebookStatsPlayerCheck) finds filed under the wrong game, for an admin to
# approve or discard on the admin pages. Approving records the decision; an
# approved suggestion's lines are then added to our batting lines only when an
# admin applies it (apply!), and can be taken out again (unapply!).
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
  belongs_to :applied_by, class_name: "User", optional: true
  has_many :lines, -> { order(:id) }, class_name: "FixSuggestionLine", dependent: :delete_all
  has_many :applied_batting_lines, class_name: "BattingLine", dependent: :restrict_with_exception

  # A change the suggestion's state doesn't allow (applying one not approved,
  # changing the decision on one applied, ...), with a message for the admin.
  class NotAllowed < StandardError; end

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
    raise NotAllowed, "成績に反映済みです。決定を変えるには、先に反映を取り消してください。" if status != "approved" && applied?

    decided = status != "pending"
    update!(status: status, decided_by: (user if decided), decided_at: (Time.current if decided), note: note.nil? ? self.note : note.presence)
  end

  # Whether any of our batting lines came from applying this suggestion.
  def applied?
    applied_batting_lines.exists?
  end

  # Whether it can be applied: approved, a misfiled_lines one with its game
  # guessed (the only kind that says where the lines go).
  def applicable?
    status == "approved" && kind == "misfiled_lines" && game.present? && university.present?
  end

  # The lines applying would add: those whose player has no batting line in the
  # guessed game yet (one imported from Scorebook, or added before, stays).
  def lines_to_apply
    return [] unless game

    have = BattingLine.where(game: game).pluck(:player_id)
    lines.reject { |line| have.include?(line.player_id) }
  end

  # Adds the lines to our batting lines, as lines of the guessed game for the
  # university, marked as this suggestion's; lines_to_apply says which. Values
  # Scorebook didn't record are 0, as the import stores them. Can be run again
  # for lines gathered since. Returns how many were added.
  def apply!(user:, now: Time.current)
    raise NotAllowed, "承認済みで、試合が1つに絞れている提案だけ反映できます。" unless applicable?

    transaction do
      rows = lines_to_apply.map { |line| batting_attributes(line, now) }
      BattingLine.insert_all!(rows) if rows.any?
      update!(applied_at: now, applied_by: user)
      rows.size
    end
  end

  # Takes the lines applying added out of our batting lines again. Returns how
  # many were removed.
  def unapply!
    transaction do
      # Not applied_batting_lines.delete_all: through the association that would
      # only clear their fix_suggestion_id, leaving them as imported lines.
      removed = BattingLine.where(fix_suggestion_id: id).delete_all
      update!(applied_at: nil, applied_by: nil)
      removed
    end
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

  # How many batting lines imported from Scorebook we already have for the
  # university in the guessed game (none, if Scorebook files them under another
  # game). Lines added by applying suggestions aren't counted.
  def our_lines_count
    return nil unless game && university

    BattingLine.where(game: game, university: university, fix_suggestion_id: nil).count
  end

  private

  def batting_attributes(line, now)
    counts = ScorebookMemberStats::FIELDS.keys.index_with { |field| line.value(field).to_i }
    total_bases = BattingLine.total_bases_of(**counts.slice(:hits, :doubles, :triples, :home_runs))

    counts.merge(
      game_id: game.id, player_id: line.player_id, university_id: university.id, fix_suggestion_id: id,
      position: line.position, total_bases: total_bases, created_at: now, updated_at: now
    )
  end
end

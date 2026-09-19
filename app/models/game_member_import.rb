# Builds GameMember rows from the GameMember lists Scorebook embeds in each
# game of a season's stored scorebook_games: who was on each team's roster for
# that game, with uniform number, grade, and role. Needs no network access, but
# only links people already imported by PlayerSync; anyone else is counted as
# skipped. Scorebook only provides these lists for 2021 onward.
#
# Each game's rows are replaced together, so re-running is safe, and a game
# whose data no longer carries a list is left as it was.
#
#   bin/rails runner script/big6/import_game_members.rb
class GameMemberImport
  def self.call(seasons = Season.where.not(scorebook_games: nil))
    new(seasons).call
  end

  def initialize(seasons)
    @seasons = seasons
  end

  # Returns { games:, members:, skipped: }; skipped counts people whose player
  # was not imported and people listed twice for the same game.
  def call
    player_ids = Player.pluck(:scorebook_id, :id).to_h
    university_ids = university_ids_by_scorebook_team_id
    totals = { games: 0, members: 0, skipped: 0 }

    @seasons.find_each do |season|
      games_by_scorebook_id = season.games.where.not(scorebook_game_id: nil).index_by(&:scorebook_game_id)

      season.scorebook_games.each do |info|
        game = games_by_scorebook_id[info["id"]]
        next unless game && info["GameMember"].present?

        rows = info["GameMember"].filter_map { |member| row_for(game, member, player_ids, university_ids) }.uniq { |row| row[:player_id] }
        totals[:skipped] += info["GameMember"].size - rows.size

        GameMember.transaction do
          game.game_members.delete_all
          GameMember.insert_all!(rows) if rows.any?
        end
        totals[:games] += 1
        totals[:members] += rows.size
      end
    end

    totals
  end

  private

  def university_ids_by_scorebook_team_id
    ids_by_slug = University.where(slug: ScorebookSync::SCOREBOOK_TEAM_SLUGS.values).pluck(:slug, :id).to_h
    ScorebookSync::SCOREBOOK_TEAM_SLUGS.filter_map { |team_id, slug| [ team_id, ids_by_slug[slug] ] if ids_by_slug[slug] }.to_h
  end

  def row_for(game, member, player_ids, university_ids)
    player_id = player_ids[member["memberId"]]
    university_id = university_ids[member["teamId"]]
    return nil unless player_id && university_id

    {
      game_id: game.id,
      player_id: player_id,
      university_id: university_id,
      uniform_number: member["number"],
      grade: member["grade"],
      role: member["startingTeamRole"].presence,
      batting_order: member["startingBatter"],
      fielding_position: member["startingPositionJp"].presence,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
end

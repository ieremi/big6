# One person on one team's roster for one game (bench included), with the
# uniform number, grade, and role listed for that game. Built by
# GameMemberImport from the GameMember lists Scorebook embeds in a season's
# game data.
class GameMember < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :university

  # Display order for a team's roster: staff (most senior first), then the
  # starters in batting order, then everyone else by uniform number. Needs
  # each member's player loaded.
  def self.roster_order(members)
    members.sort_by do |member|
      staff_rank = Player::STAFF_ROLES.index(member.role)
      group = staff_rank ? 0 : (member.batting_order ? 1 : 2)
      [ group, staff_rank || 0, member.batting_order || 0, member.uniform_number || 999, member.player.name ]
    end
  end
end

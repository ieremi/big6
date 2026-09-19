# One person on one team's roster for one game (bench included), with the
# uniform number, grade, and role listed for that game. Built by
# GameMemberImport from the GameMember lists Scorebook embeds in a season's
# game data.
class GameMember < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :university
end

class Game < ApplicationRecord
  belongs_to :season
  belongs_to :team0, class_name: "University"
  belongs_to :team1, class_name: "University"
end

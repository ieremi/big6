Season.where.not(scorebook_games: nil).find_each do |season|
  season.scorebook_games.each do |info|
    # info 1件 = Scorebook の1試合
    p h = {
      played_on: info["gameDay"],
      top_team: info.dig("topTeam", "id"),
      bottom_team: info.dig("bottomTeam", "nameShort"),
      run: info["runsTotalTop"],
      attendance: info.dig("attendance")
    }
  end
end

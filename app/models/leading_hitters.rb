# Every season's 首位打者 (batting champion), as the league lists them, for the
# article on the ones who won it as 1年生 (/articles/freshman-leading-hitters):
# read from db/articles/leading_hitters.yml, which keys each one by Scorebook id,
# with the player's year at the time worked out from the entry year in the 名鑑
# (Player#enter_year).
#
# A year is counted from the entry year: the spring and autumn of the year of
# entry are the 1年, and so on. Before and during the war, when many came up
# through a 予科 or were away for years, some champions' entry years are five
# or more years before; their year isn't counted (nil), as it can't be told.
#
# The season being played (once its box scores are in, and before the league
# lists its champion) comes from the league's own way of ranking, PlayerRanking
# with its minimum, so the article can say which 1年生 lead it so far.
class LeadingHitters
  # A champion: the season ([year, "spring" / "autumn" / "single"]), the name as
  # the league lists it, the university, the Scorebook id (nil when not in the
  # 名鑑) and the player, and the line the league lists.
  Champion = Data.define(:year, :term, :name, :university, :scorebook_id, :player, :games, :ab, :hits) do
    def average
      hits.to_f / ab
    end

    # 1 to 4 (年生), or nil when it can't be told.
    def grade
      return nil unless player&.enter_year

      (year - player.enter_year + 1).then { |grade| grade if grade.between?(1, 4) }
    end

    def freshman?
      grade == 1
    end

    # 「1992年春季」, or 「1933年」 for a year of one season.
    def season_title
      term == "single" ? "#{year}年" : "#{year}年#{term == "spring" ? "春季" : "秋季"}"
    end
  end

  def self.path
    Rails.root.join("db/articles/leading_hitters.yml")
  end

  def self.data
    YAML.safe_load_file(path)
  end

  # Every champion, oldest first.
  def self.all
    entries = data.fetch("champions")
    universities = University.all.index_by(&:slug)
    players = Player.where(scorebook_id: entries.filter_map { |entry| entry["scorebook_id"] }).index_by(&:scorebook_id)
    entries.map do |entry|
      year, term = entry.fetch("season").split("-")
      Champion.new(year: year.to_i, term:, name: entry.fetch("name"), university: universities.fetch(entry.fetch("university")),
        scorebook_id: entry["scorebook_id"], player: players[entry["scorebook_id"]], games: entry.fetch("games"), ab: entry.fetch("ab"), hits: entry.fetch("hits"))
    end
  end

  # { "name" => ..., "url" => ... } of the league's list.
  def self.source
    data.fetch("source")
  end

  # The season being played, after the last listed: the league's batting ranking
  # (PlayerRanking with the league's minimum, by average) so far. nil when there
  # is none, or its champion is already listed.
  def self.current(champions = all)
    season = PlayerRanking.seasons_with_stats("batting").first
    return nil unless season

    last = champions.last
    return nil if last && (season.year < last.year || (season.year == last.year && (season.term == "spring" || last.term != "spring")))

    PlayerRanking.new("batting", season:, minimum: PlayerRanking::LEAGUE, order_by: "average")
  end
end

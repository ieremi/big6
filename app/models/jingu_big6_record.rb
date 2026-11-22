# How 東京六大学's entrants have done in the 大学の部 of the 明治神宮野球大会
# (神宮大会), every year it was held from 1970, for the article at
# /articles/jingu-big6-record: read from db/articles/jingu_big6.yml, which says
# who went and how far, and from 2013 each of their games.
#
# The entrant is the autumn league's champion as a rule, but some years its
# runner-up went instead (1971, 1980, 1987, 1994, 1998), and in 1972, 1975 and
# 1976 the league had more than one place. The champion each year is the
# site's own (SeasonChampion), so the article can say which years those were;
# the sources don't say why.
class JinguBig6Record
  RESULTS = { "champion" => "優勝", "runner_up" => "準優勝", "semifinal" => "ベスト4", "early" => "ベスト4に届かず" }.freeze

  Entrant = Data.define(:university, :result) do
    def result_label = RESULTS.fetch(result)
  end

  Game = Data.define(:round, :opponent, :runs, :allowed) do
    def won? = runs > allowed
  end

  # A tournament: its year, its number (第1回 in 1970), the 東京六大学 entrants,
  # the entrant's games (from 2013), and the autumn champion of the league.
  Year = Data.define(:year, :entrants, :games, :autumn_champion) do
    def edition = year - 1969

    # Whether the league's autumn champion wasn't among the entrants (none
    # known for a season the data has no champion of).
    def without_champion? = autumn_champion && entrants.none? { |entrant| entrant.university == autumn_champion }
  end

  # How many times a university went, and how far: { result => count }.
  Tally = Data.define(:university, :entries, :results)

  def initialize(path: Rails.root.join("db/articles/jingu_big6.yml"))
    @data = YAML.load_file(path)
  end

  def source(key) = @data.fetch("sources").fetch(key)

  def cancelled = @data.fetch("cancelled")

  # Every tournament held, oldest first.
  def years
    @years ||= begin
      universities = University.all.index_by(&:slug)
      seasons = Season.select(:id, :year, :term).where(term: "autumn", year: @data["years"].map { |year| year["year"] }).index_by(&:year)
      @data.fetch("years").map do |year|
        Year.new(
          year: year["year"],
          entrants: year["entrants"].map { |entrant| Entrant.new(university: universities.fetch(entrant["university"]), result: entrant["result"]) },
          games: Array(year["games"]).map { |game| Game.new(**game.symbolize_keys.slice(:round, :opponent, :runs, :allowed)) },
          autumn_champion: seasons[year["year"]]&.then { |season| SeasonChampion.of(season) }
        )
      end
    end
  end

  def entrants = years.flat_map(&:entrants)

  # { result => count } over every entrant.
  def results = RESULTS.keys.index_with { |result| entrants.count { |entrant| entrant.result == result } }

  # Each university's entries and results, most titles first.
  def by_university
    entrants.group_by(&:university).map do |university, list|
      Tally.new(university:, entries: list.size, results: RESULTS.keys.index_with { |result| list.count { |entrant| entrant.result == result } })
    end.sort_by { |tally| [ -tally.results["champion"], -tally.results["runner_up"], -tally.entries, tally.university.position ] }
  end

  # { decade => [tournaments held, { result => count }] }: 1970 for the 1970s.
  def by_decade
    years.group_by { |year| year.year / 10 * 10 }.transform_values do |list|
      [ list.size, RESULTS.keys.index_with { |result| list.flat_map(&:entrants).count { |entrant| entrant.result == result } } ]
    end
  end

  # The years the autumn champion didn't go, each with its entrant's place in
  # the autumn standings: [Year, Entrant, place].
  def without_champion
    years.select(&:without_champion?).flat_map do |year|
      standings = Standings.new(Season.select(:id, :year, :term).find_by!(year: year.year, term: "autumn"))
      year.entrants.map { |entrant| [ year, entrant, standings.row_for(entrant.university).rank ] }
    end
  end

  # The years with games, oldest first, and the entrants' games won and lost in them.
  def years_with_games = years.select { |year| year.games.any? }

  def games_record
    games = years.flat_map(&:games)
    [ games.count(&:won?), games.count { |game| game.runs < game.allowed } ]
  end
end

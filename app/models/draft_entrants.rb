# The 東京六大学 players who filed プロ野球志望届 for a year's draft, and who was
# picked, for that year's article (/articles/draft-2026): read from
# db/articles/draft_<year>.yml, which keys each player by Scorebook id, with
# what we have of him (Player) and the titles his university won while he was
# there.
#
# "While he was there" is the four years from his entry year (Player#enter_year):
# its spring season to the autumn season three years on, whether or not he
# played in them. Only seasons that are over are counted; the draft comes before
# the autumn season ends, and its title is counted once it is decided.
class DraftEntrants
  # A pick: the team, the round, and whether in the 育成 draft.
  Pick = Struct.new(:team, :round, :position, :development, keyword_init: true) do
    # "1位", or "育成1位".
    def label
      "#{"育成" if development}#{round}位"
    end
  end

  # One player who filed: the player, the day his league received it, his pick
  # (nil when not picked), the seasons his university won while he was there,
  # and his league career at the plate and on the mound (a BattingLine::Totals
  # with at-bats and hits, a PitchingLine::Totals with outs and earned runs; 0
  # for none), the playoffs left out as on his page (PlayerStats).
  Entrant = Struct.new(:player, :university, :filed_on, :pick, :titles, :seasons_counted, :batting, :pitching, keyword_init: true) do
    def picked?
      pick.present?
    end
  end

  attr_reader :year

  def self.path(year)
    Rails.root.join("db/articles/draft_#{year}.yml")
  end

  def initialize(year)
    @year = year
    @data = YAML.safe_load_file(self.class.path(year), permitted_classes: [ Date ])
  end

  def held_on
    @data.fetch("held_on")
  end

  # [{ "name" =>, "url" => }, ...]
  def sources
    @data.fetch("sources")
  end

  # Every player who filed, in the order of the universities, then picked ones
  # first by round, then by the day they filed.
  def entrants
    @entrants ||= begin
      players = Player.where(scorebook_id: rows.map { |row| row.fetch("scorebook_id") }).includes(:university).index_by(&:scorebook_id)
      batting = career_sums(BattingLine, players.values, :ab, :hits)
      pitching = career_sums(PitchingLine, players.values, :outs, :earned_runs)
      rows.map do |row|
        player = players.fetch(row.fetch("scorebook_id")) { raise KeyError, "no player #{row["scorebook_id"]} (#{row["name"]}) in #{self.class.path(year)}" }
        seasons = seasons_while_there(player)
        Entrant.new(
          player: player, university: player.university, filed_on: row.fetch("filed_on"),
          pick: row["pick"] && Pick.new(**row["pick"].symbolize_keys.slice(:team, :round, :position, :development)),
          titles: seasons.select { |season| champions[season.id] == player.university }, seasons_counted: seasons,
          batting: BattingLine::Totals.new(**batting.fetch(player.id, { ab: 0, hits: 0 })),
          pitching: PitchingLine::Totals.new(**pitching.fetch(player.id, { outs: 0, earned_runs: 0 }))
        )
      end.sort_by { |entrant| [ entrant.university.position, entrant.picked? ? 0 : 1, entrant.pick&.development ? 1 : 0, entrant.pick&.round.to_i, entrant.filed_on, entrant.player.scorebook_id ] }
    end
  end

  # The players picked, in the order of the draft: round, the 育成 draft after.
  def picked
    entrants.select(&:picked?).sort_by { |entrant| [ entrant.pick.development ? 1 : 0, entrant.pick.round, entrant.university.position ] }
  end

  # The universities that had a player file, in their order, with how many filed and how many were picked.
  def by_university
    entrants.group_by(&:university).map { |university, list| [ university, list.size, list.count(&:picked?) ] }
  end

  # A season of the draft's year still being played, whose title isn't counted yet.
  def season_in_progress
    Season.select(:id, :year, :term, :scorebook_games).where(year: year).order(:term).find { |season| !season.finished? }
  end

  private

  def rows
    @data.fetch("players")
  end

  # { player id => { column => sum } } of the players' lines in the games counted
  # in stats (no playoff), in one query for them all.
  def career_sums(line_class, players, *columns)
    table = line_class.table_name
    line_class.joins(:game).where(player_id: players.map(&:id), games: { counted_in_stats: true }).group(:player_id)
      .pluck(:player_id, *columns.map { |column| Arel.sql("SUM(#{table}.#{column})") })
      .to_h { |player_id, *sums| [ player_id, columns.zip(sums.map(&:to_i)).to_h ] }
  end

  # The seasons over among the four years from the player's entry year.
  def seasons_while_there(player)
    return [] unless player.enter_year

    seasons.select { |season| season.year.between?(player.enter_year, player.enter_year + 3) && finished.include?(season.id) }
  end

  # The seasons of the four years before the draft (every entrant's), oldest first, without their Scorebook columns.
  def seasons
    @seasons ||= Season.select(:id, :year, :term).where(year: (year - 6)..year).to_a.sort_by { |season| [ season.year, season.term == "spring" ? 0 : 1 ] }
  end

  def finished
    @finished ||= Season.select(:id, :scorebook_games).where(id: seasons.map(&:id)).select(&:finished?).map(&:id).to_set
  end

  # { season id => its champion } for the seasons over (SeasonChampion: a playoff's winner when there was one).
  def champions
    @champions ||= seasons.select { |season| finished.include?(season.id) }.to_h { |season| [ season.id, SeasonChampion.of(season) ] }
  end
end

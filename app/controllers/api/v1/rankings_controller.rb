module Api
  module V1
    class RankingsController < BaseController
      PER_PAGE = 100

      # GET /api/v1/rankings/batting and /api/v1/rankings/pitching: the whole career unless
      # year and term name a season; university[] limits it to those universities;
      # minimum is the least plate appearances (batting) or innings (pitching) to be ranked.
      # sort and direction reorder the rows, and rank is then the position in that order;
      # default_rank is always the rank in the default order (OPS for batting, ERA for pitching).
      def show
        season = Season.find_by!(year: params[:year], term: params[:term]) if params[:year].present? && params[:term].present?
        ranking = PlayerRanking.new(params[:kind], season: season, university_ids: university_ids_from_params, minimum: PlayerRanking.minimum_from(params[:minimum]))
        sort = PlayerRanking.sort_keys(ranking.kind).include?(params[:sort]) ? params[:sort] : "rank"
        direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : PlayerRanking.default_direction(ranking.kind, sort)
        entries = ranking.entries_sorted_by(sort, direction)
        page = [ params[:page].to_i, 1 ].max

        render json: {
          kind: ranking.kind,
          season: season && season_json(season),
          minimum: { (ranking.kind == "batting" ? :plate_appearances : :innings) => ranking.minimum },
          sort: sort,
          direction: direction,
          total: entries.size,
          page: page,
          per_page: PER_PAGE,
          rankings: (entries.slice((page - 1) * PER_PAGE, PER_PAGE) || []).map { |entry| entry_json(ranking.kind, entry) }
        }
      end

      private

      def entry_json(kind, entry)
        player = { id: entry.player.scorebook_id, name: entry.player.name, university: entry.player.university.slug }
        totals = entry.totals

        if kind == "batting"
          {
            rank: entry.rank, default_rank: entry.default_rank, player: player,
            ops: totals.ops, obp: totals.on_base_percentage, slg: totals.slugging_percentage, average: totals.average,
            games: totals.games, pa: totals.pa, ab: totals.ab, hits: totals.hits, home_runs: totals.home_runs, total_bases: totals.total_bases
          }
        else
          {
            rank: entry.rank, default_rank: entry.default_rank, player: player,
            era: totals.era, games: totals.games, started: totals.started, wins: totals.wins, losses: totals.losses,
            outs: totals.outs, innings: PitchingLine.innings_label(totals.outs), hits: totals.hits, home_runs: totals.home_runs,
            strikeouts: totals.strikeouts, walks: totals.walks, earned_runs: totals.earned_runs
          }
        end
      end
    end
  end
end

module Api
  module V1
    class RankingsController < BaseController
      PER_PAGE = 100

      # GET /api/v1/rankings/batting and /api/v1/rankings/pitching: the whole career unless
      # year and term name a season; university[] limits it to those universities;
      # minimum is the least plate appearances (batting) or innings (pitching) to be ranked.
      # sort and direction reorder the rows (comma-separated lists of up to three columns,
      # each breaking the ties of the ones before, see SortOrder), and rank is then the position in that order;
      # default_rank is always the rank in the default order (OPS for batting, ERA for pitching).
      def show
        season = Season.find_by!(year: params[:year], term: params[:term]) if params[:year].present? && params[:term].present?
        ranking = PlayerRanking.new(params[:kind], season: season, university_ids: university_ids_from_params, minimum: PlayerRanking.minimum_from(params[:minimum]))
        order = PlayerRanking.sort_order(ranking.kind, params[:sort], params[:direction]).or(PlayerRanking::DEFAULT_KEY)
        entries = ranking.entries_sorted(order)
        page = [ params[:page].to_i, 1 ].max

        render json: {
          kind: ranking.kind,
          season: season && season_json(season),
          minimum: { (ranking.kind == "batting" ? :plate_appearances : :innings) => ranking.minimum },
          sort: order.sort_param,
          direction: order.direction_param,
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

module Api
  module V1
    class PlayersController < BaseController
      PER_PAGE = 100

      def index
        search = PlayerSearch.new(
          keyword: params[:q], university_ids: university_ids_from_params,
          start_year: params[:start_year], end_year: params[:end_year], role_group: params[:role], status: params[:status]
        )
        total = search.players.count
        page = [ params[:page].to_i, 1 ].max
        players = search.ordered.offset((page - 1) * PER_PAGE).limit(PER_PAGE)

        render json: { total: total, page: page, per_page: PER_PAGE, players: players.map { |player| player_json(player) } }
      end

      def show
        player = find_player
        stats = PlayerStats.new(player)

        render json: player_json(player).merge(batting: batting_json(stats), pitching: pitching_json(stats))
      end

      # The player's games, most recent first: the roster entry, batting line,
      # and pitching line of each game they have any of.
      def games
        player = find_player
        stats = PlayerStats.new(player)

        entries = {}
        entry_for = ->(game, university_id) { entries[game.id] ||= { game: game, university_id: university_id } }
        stats.batting_lines.each { |line| entry_for.call(line.game, line.university_id)[:batting] = line }
        stats.pitching_lines.each { |line| entry_for.call(line.game, line.university_id)[:pitching] = line }
        player.game_members.includes(game: [ :season, :team0, :team1 ]).each { |member| entry_for.call(member.game, member.university_id)[:roster] = member }

        sorted = entries.values.sort_by { |entry| [ entry[:game].played_on, entry[:game].game_number ] }.reverse
        render json: sorted.map { |entry| game_entry_json(entry) }
      end

      # The same image the player page uses for og:image.
      def og_image
        send_data PlayerOgImage.new(find_player).to_png, type: "image/png", disposition: "inline"
      end

      private

      def find_player
        Player.includes(:university).find_by!(scorebook_id: params[:id])
      end

      # nil (any university) unless university[] is given; slugs that match no
      # university leave nobody, as the games search does.
      def university_ids_from_params
        return nil if params[:university].blank?

        University.where(slug: Array(params[:university])).pluck(:id)
      end

      # The id is the player's Scorebook id, as in the site's /players/:id URLs,
      # rather than our internal database id.
      def player_json(player)
        {
          id: player.scorebook_id,
          name: player.name,
          name_kana: player.name_kana,
          university: player.university.slug,
          enter_year: player.enter_year,
          role: player.role,
          position: player.position,
          batting_hand: player.batting_hand,
          pitching_hand: player.pitching_hand,
          high_school: player.high_school,
          faculty: player.faculty,
          grade: player.grade,
          status: player.enrollment_state,
          og_image_url: api_v1_player_og_image_url(player)
        }
      end

      # null when the player has no batting (or pitching) stats.
      def batting_json(stats)
        return nil unless stats.batting?

        {
          seasons: stats.batting_seasons.map { |row| season_json(row.season).merge(batting_totals_json(row.totals)) },
          career: batting_totals_json(stats.batting_total)
        }
      end

      def pitching_json(stats)
        return nil unless stats.pitching?

        {
          seasons: stats.pitching_seasons.map { |row| season_json(row.season).merge(pitching_totals_json(row.totals)) },
          career: pitching_totals_json(stats.pitching_total)
        }
      end

      def batting_totals_json(totals)
        {
          games: totals.games, average: totals.average,
          obp: totals.on_base_percentage, slg: totals.slugging_percentage, ops: totals.ops,
          **batting_counts_json(totals)
        }
      end

      def pitching_totals_json(totals)
        {
          games: totals.games, era: totals.era,
          **pitching_counts_json(totals),
          started: totals.started, complete_game: totals.complete_game, shutout: totals.shutout, wins: totals.wins, losses: totals.losses
        }
      end

      # The counting stats a total and a single game's line have in common.
      def batting_counts_json(source)
        {
          pa: source.pa, ab: source.ab, runs: source.runs, hits: source.hits, doubles: source.doubles, triples: source.triples,
          home_runs: source.home_runs, total_bases: source.total_bases, rbi: source.rbi, strikeouts: source.strikeouts, walks: source.walks,
          sacrifices: source.sacrifices, stolen_bases: source.stolen_bases, gidp: source.gidp, fielding_errors: source.fielding_errors
        }
      end

      # outs is exact; innings is the same thing as baseball writes it ("50 1/3").
      def pitching_counts_json(source)
        {
          outs: source.outs, innings: PitchingLine.innings_label(source.outs), batters_faced: source.batters_faced,
          hits: source.hits, home_runs: source.home_runs, walks: source.walks, strikeouts: source.strikeouts,
          runs: source.runs, earned_runs: source.earned_runs
        }
      end

      def game_entry_json(entry)
        game = entry[:game]
        opponent = game.team0_id == entry[:university_id] ? game.team1 : game.team0

        {
          game: game_ref_json(game).merge(played_on: game.played_on),
          opponent: opponent.slug,
          counted_in_stats: game.counted_in_stats,
          roster: entry[:roster] && roster_json(entry[:roster]),
          batting: entry[:batting] && batting_line_json(entry[:batting]),
          pitching: entry[:pitching] && pitching_line_json(entry[:pitching])
        }
      end

      def roster_json(member)
        {
          uniform_number: member.uniform_number, grade: member.grade, role: member.role,
          batting_order: member.batting_order, fielding_position: member.fielding_position
        }
      end

      def batting_line_json(line)
        { position: line.position, **batting_counts_json(line) }
      end

      def pitching_line_json(line)
        {
          **pitching_counts_json(line), pitches: line.pitches,
          started: line.started.positive?, complete_game: line.complete_game.positive?, shutout: line.shutout.positive?,
          result: (line.wins.positive? ? "win" : (line.losses.positive? ? "loss" : nil))
        }
      end
    end
  end
end

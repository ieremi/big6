class UniversitiesController < ApplicationController
  def index
    @universities = University.order(:position)
  end

  def show
    @university = University.find_by!(slug: params[:slug])
    @opponents = University.where.not(id: @university.id).order(:position).to_a
    @record = TeamRecord.new(@university)
    @roster = UniversityRoster.new(@university)

    # The university's latest season with games (only the columns shown, not the
    # season's Scorebook JSONB), and its games in it. "autumn" sorts before
    # "spring", so term ascending puts a year's autumn first.
    team_games = Game.where(team0_id: @university.id).or(Game.where(team1_id: @university.id))
    @games_season = Season.select(:id, :year, :term).where(id: team_games.select(:season_id)).order(year: :desc, term: :asc).first
    @season_games = @games_season ? team_games.where(season_id: @games_season.id).includes(:team0, :team1).order(:played_on, :game_number).to_a : []

    latest_season_id = Game.order(played_on: :desc, game_number: :desc).limit(1).pick(:season_id)
    @periods = {
      "all" => {},
      "20" => { since: 20.years.ago.to_date },
      "10" => { since: 10.years.ago.to_date },
      "5" => { since: 5.years.ago.to_date },
      "r" => { season_id: latest_season_id }
    }
  end

  def og_image
    send_data SiteOgImage.new(title: "Universities").to_png, type: "image/png", disposition: "inline"
  end

  def show_og_image
    university = University.find_by!(slug: params[:slug])

    send_data OgImages.university(university), type: "image/png", disposition: "inline"
  end
end

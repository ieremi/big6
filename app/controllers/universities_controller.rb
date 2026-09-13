class UniversitiesController < ApplicationController
  def index
    @universities = University.order(:position)
  end

  def show
    @university = University.find_by!(slug: params[:slug])
    @opponents = University.where.not(id: @university.id).order(:position).to_a
    @record = TeamRecord.new(@university)

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
end

class UniversitiesController < ApplicationController
  def index
    @universities = University.order(:position)
  end

  def og_image
    send_data SiteOgImage.new(title: "Universities").to_png, type: "image/png", disposition: "inline"
  end
end

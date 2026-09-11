class HomeController < ApplicationController
  def index
  end

  def og_image
    title = params[:title].presence || "Tokyo Big 6 Baseball"
    subtitle = params[:subtitle].presence

    send_data SiteOgImage.new(title: title, subtitle: subtitle).to_png, type: "image/png", disposition: "inline"
  end
end

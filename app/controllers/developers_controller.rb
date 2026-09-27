# The developers' notes (docs/, see DeveloperDoc): /developers is the index,
# /developers/<name> each page.
class DevelopersController < ApplicationController
  def show
    @doc = DeveloperDoc.find(params[:page]) or raise ActionController::RoutingError, "no such page"
  end
end

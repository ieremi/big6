class UniversitiesController < ApplicationController
  def index
    @universities = University.order(:position)
  end
end

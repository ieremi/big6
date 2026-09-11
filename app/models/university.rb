class University < ApplicationRecord
  COLORS = {
    "waseda" => "#7c1d3f",
    "keio" => "#1e2a5e",
    "meiji" => "#5b2d82",
    "hosei" => "#f2861d",
    "tokyo" => "#5bb8e8",
    "rikkio" => "#9b7fc7"
  }.freeze

  INITIALS = {
    "waseda" => "W",
    "keio" => "K",
    "meiji" => "M",
    "hosei" => "H",
    "tokyo" => "T",
    "rikkio" => "R"
  }.freeze

  def color
    COLORS.fetch(slug, "#64748b")
  end

  def initial
    INITIALS.fetch(slug, short_name.delete_suffix("大"))
  end
end

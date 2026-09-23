# The OG image for a university's season list: on the university's colour, its
# initial large, the season beneath, then its opponents in the order it played
# them, each as a chip in the opponent's colour with the season's week number
# under it:
#
#          R
#     2026 Autumn
#       H  K  T  W  M
#   week 2  3  5  6  8
#   Tokyo Big 6 Baseball
class TeamSeasonOgImage < OgImage
  CHIP_SIZE = 110
  CHIP_BORDER = 4
  MAX_COLUMN_WIDTH = 170
  COLUMNS_WIDTH = 840 # the widest the opponents' columns get, for a long season
  CHIPS_Y = 345
  WEEKS_Y = 455

  # opponents: [[week number, University], ...], in the order they were played.
  def initialize(team, title:, opponents:)
    @team = team
    @title = title
    @opponents = opponents
  end

  def to_png
    bg = solid_background(@team.color)
    centers = column_centers

    # The chips go on first, while the background is still three bands (the text
    # drawn after it adds an alpha band, and insert needs the bands to match).
    @opponents.each_with_index do |(_, opponent), index|
      bg = chip(bg, opponent, center_x: centers[index])
    end

    bg, = overlay_text(bg, @team.initial, dpi: 1000, center_y: 95)
    bg, = overlay_text(bg, @title, dpi: 400, center_y: 225)

    chip_initial_dpi = dpi_to_fit("W", CHIP_SIZE * 0.5)
    week_dpi = 370
    label_dpi = 250
    @opponents.each_with_index do |(week, opponent), index|
      bg, = overlay_text(bg, opponent.initial, dpi: chip_initial_dpi, center_x: centers[index], center_y: CHIPS_Y)
      bg, = overlay_text(bg, week.to_s, dpi: week_dpi, center_x: centers[index], center_y: WEEKS_Y)
    end
    if centers.any?
      label_x = centers.first - column_width * 0.5 - text_width("week", label_dpi) / 2.0 - 10
      bg, = overlay_text(bg, "week", dpi: label_dpi, center_x: label_x, center_y: WEEKS_Y)
    end

    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: 200, center_y: 570)

    finalize(bg)
  end

  private

  def column_width
    return MAX_COLUMN_WIDTH if @opponents.empty?

    [ MAX_COLUMN_WIDTH, COLUMNS_WIDTH / @opponents.size ].min
  end

  # The x of each opponent's column, the columns centred on the image.
  def column_centers
    left = WIDTH / 2.0 - column_width * @opponents.size / 2.0
    @opponents.each_index.map { |index| left + column_width * (index + 0.5) }
  end

  # A square in the opponent's colour with a white border, centred on center_x
  # in the chips' row.
  def chip(bg, opponent, center_x:)
    outer = CHIP_SIZE + CHIP_BORDER * 2
    border = (Vips::Image.black(outer, outer) + [ 255, 255, 255 ]).cast(:uchar)
    fill = (Vips::Image.black(CHIP_SIZE, CHIP_SIZE) + hex_to_rgb(opponent.color)).cast(:uchar)
    square = border.insert(fill, CHIP_BORDER, CHIP_BORDER).copy(interpretation: :srgb)

    bg.insert(square, (center_x - outer / 2.0).round, (CHIPS_Y - outer / 2.0).round)
  end
end

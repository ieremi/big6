require "test_helper"

class PlayerOgImageTest < ActiveSupport::TestCase
  def png_for(player)
    Vips::Image.new_from_buffer(PlayerOgImage.new(player).to_png, "")
  end

  def player(**attributes)
    Player.new({ name: "落合 智哉", university: universities(:one), enter_year: 2023, role: "選手", position: "捕手", pitching_hand: "右", batting_hand: "右" }.merge(attributes))
  end

  test "renders a 1200x630 PNG" do
    image = png_for(player)

    assert_equal [ 1200, 630 ], [ image.width, image.height ]
  end

  test "renders staff with no entry year, position, or hands" do
    image = png_for(player(name: "日野 愛郎", role: "部長", enter_year: nil, position: nil, pitching_hand: nil, batting_hand: nil))

    assert_equal [ 1200, 630 ], [ image.width, image.height ]
  end

  test "renders names containing Pango markup characters" do
    assert_nothing_raised { png_for(player(name: "A&B <C> 太郎")) }
  end

  test "renders a very long name" do
    assert_nothing_raised { png_for(player(name: "アレクサンダー ジョンソン ジュニア 三世")) }
  end
end

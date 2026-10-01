require "test_helper"

class Api::V1::SeasonsControllerTest < ActionDispatch::IntegrationTest
  test "lists the seasons newest first, autumn before spring within a year" do
    Season.create!(year: 2025, term: "autumn")

    get "/api/v1/seasons"

    assert_equal [ [ 2026, "autumn" ], [ 2026, "spring" ], [ 2025, "autumn" ] ], response.parsed_body.map { |season| season.values_at("year", "term") }
  end
end

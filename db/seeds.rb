# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

University.create!([
  { name: "早稲田大学",   short_name: "早大", slug: "waseda" },
  { name: "慶應義塾大学", short_name: "慶大", slug: "keio" },
  { name: "明治大学",     short_name: "明大", slug: "meiji" },
  { name: "法政大学",     short_name: "法大", slug: "hosei" },
  { name: "東京大学",     short_name: "東大", slug: "tokyo" },
  { name: "立教大学",     short_name: "立大", slug: "rikkyo" }
])
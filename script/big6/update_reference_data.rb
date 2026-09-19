# Refreshes the Prime Minister and GDP per capita data shown on season pages
# from Wikidata and the World Bank (see ReferenceDataSync). Re-run it when a
# Prime Minister changes or the World Bank publishes another year.
#
# Run with: bin/rails runner script/big6/update_reference_data.rb
result = ReferenceDataSync.call
puts "prime minister terms: #{result[:prime_minister_terms]}"
puts "GDP per capita years: #{result[:gdp_years].join('-')}"

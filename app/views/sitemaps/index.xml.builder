xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.sitemapindex xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @parts.each do |loc, lastmod|
    xml.sitemap do
      xml.loc loc
      xml.lastmod lastmod.strftime("%Y-%m-%d") if lastmod
    end
  end
end

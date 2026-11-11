# パンくずリスト: where a page sits on the site, from the top down, shown above
# its heading (the layout yields :breadcrumbs) and given to search engines as a
# schema.org BreadcrumbList. A page sets its own trail; the top page has none.
module BreadcrumbsHelper
  # The page's trail after トップ, as [label, path] pairs from the top down; the
  # last is the page itself and needs no path.
  #
  #   breadcrumbs [ "シーズン一覧", seasons_path ], [ "2026年秋季" ]
  def breadcrumbs(*crumbs)
    content_for :breadcrumbs, render("shared/breadcrumbs", crumbs: [ [ "トップ", root_path ], *crumbs ])
  end

  # The BreadcrumbList for those crumbs, each with its absolute URL (the last,
  # the page itself, with the page's own).
  def breadcrumb_list_data(crumbs)
    {
      "@type" => "BreadcrumbList",
      "itemListElement" => crumbs.each_with_index.map do |(label, path), index|
        { "@type" => "ListItem", "position" => index + 1, "name" => label, "item" => request.base_url + (path || request.path) }
      end
    }
  end
end

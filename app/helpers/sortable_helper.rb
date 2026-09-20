# Column headings that sort a table, in two kinds:
#
# * sortable_link_header, for a table the server sorts (a paged list): a link to
#   the same page with sort and direction in the query.
# * sortable_column_header, for a table the browser sorts (the sortable-table
#   Stimulus controller): a button.
#
# Both carry a shortcut key, shown in the heading and in the ? help. Shortcuts
# are capital letters, so they don't collide with the lower-case ones.
module SortableHelper
  # sort and direction are what the table is sorted by now; a click on that column
  # reverses it, and a click on any other starts with `first` ("asc" or "desc").
  def sortable_link_header(key, label, shortcut, sort:, direction:, first: "asc")
    active = sort == key
    classes = [ "sortable" ]
    classes << (direction == "asc" ? "sorted-asc" : "sorted-desc") if active

    next_direction = active ? (direction == "asc" ? "desc" : "asc") : first
    query = request.query_parameters.except("page").merge("sort" => key, "direction" => next_direction)

    tag.th(class: classes, aria: { sort: (active ? (direction == "asc" ? "ascending" : "descending") : nil) }) do
      link_to "#{request.path}?#{query.to_query}", data: { shortcut: shortcut, shortcut_label: "#{label}でソート" } do
        safe_join([ label, " ", tag.kbd(shortcut) ])
      end
    end
  end

  # A heading for a table in a sortable-table controller. Columns that hold
  # numbers should give each cell a data-sort-value (see sort_cell); `first` is
  # the direction of the first click. Several tables on a page can share a
  # shortcut: it sorts them all.
  def sortable_column_header(label, shortcut, first: "asc", shortcut_label: nil, title: nil)
    tag.th(class: "sortable", title: title) do
      tag.button(type: "button", class: "sort-button", data: {
        action: "sortable-table#sort", sortable_table_first_param: first,
        shortcut: shortcut, shortcut_all: true, shortcut_label: "#{shortcut_label || label}でソート"
      }) { safe_join([ label, " ", tag.kbd(shortcut) ]) }
    end
  end

  # A cell whose value for sorting differs from what it shows (a rate shown as
  # ".333", innings as "5 1/3"); nil sorts last.
  def sort_cell(display, value)
    tag.td(display, data: { sort_value: value })
  end
end

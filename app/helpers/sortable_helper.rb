# Column headings that sort a table, in two kinds:
#
# * sortable_link_header, for a table the server sorts (a paged list): a link to
#   the same page with sort and direction in the query (a SortOrder: up to three
#   columns, the one clicked first).
# * sortable_column_header, for a table the browser sorts (the sortable-table
#   Stimulus controller): a button.
#
# Both carry a shortcut key, shown in the heading and in the ? help. Shortcuts
# are capital letters, so they don't collide with the lower-case ones.
module SortableHelper
  # order (a SortOrder) is what the table is sorted by now, and default the key it
  # is sorted by when order is empty. A click on the first key reverses it; a click
  # on any other column makes it the first key, starting with `first` ("asc" or
  # "desc"), and moves the others down (see SortOrder#clicked).
  def sortable_link_header(key, label, shortcut, order:, default: nil, first: "asc")
    shown = order.or(default)
    sorted = shown.key_for(key)
    next_order = order.clicked(key, first: first, default: default)
    query = request.query_parameters.except("page", "sort", "direction").merge(next_order.to_params)

    tag.th(**sorted_heading_attributes(shown, sorted, "sortable")) do
      link_to "#{request.path}?#{query.to_query}", data: { shortcut: shortcut, shortcut_label: "#{label}でソート" } do
        safe_join([ label, " ", tag.kbd(shortcut) ])
      end
    end
  end

  # The class, key number (data-sort-rank, shown only when the table is sorted by
  # more than one key) and aria-sort (on the first key only, as ARIA allows one
  # per table) of a heading of a sorted table.
  def sorted_heading_attributes(shown, sorted, *classes)
    classes << (sorted.desc? ? "sorted-desc" : "sorted-asc") if sorted
    {
      class: classes.presence,
      aria: { sort: (sorted.desc? ? "descending" : "ascending" if sorted == shown.primary) },
      data: { sort_rank: (shown.rank(sorted.column) if sorted && shown.keys.size > 1) }
    }
  end

  # A link back to the table's own order, shown while it is sorted by any key.
  def sort_reset_link(order, path: nil)
    return if order.empty?

    query = request.query_parameters.except("page", "sort", "direction")
    link_to "並べ替えをリセット", [ path || request.path, query.to_query.presence ].compact.join("?"), class: "period-btn sort-reset"
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

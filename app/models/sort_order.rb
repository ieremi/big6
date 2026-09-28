# The order a table sorted on the server is in: up to MAX_KEYS columns (並べ替え
# のキー), the first deciding the order and each next one breaking the ties of the
# ones before it. Shared by the games tables (GameSortable), the players list
# (PlayerSearch) and the rankings (PlayerRanking), on the pages and in the Web API.
#
# A click on a column's heading makes it the first key and moves the others down
# (clicked); a click on the first key reverses it. This is how the tables sorted
# in the browser (sortable_table_controller.js) behave too.
#
# In a URL it is two comma-separated lists read side by side:
# sort=attendance,date&direction=desc,asc. A single column (sort=date&direction=desc)
# reads as it always has. Unknown columns are dropped, and a column without a
# valid direction gets its default one.
class SortOrder
  MAX_KEYS = 3
  DIRECTIONS = %w[asc desc].freeze

  Key = Data.define(:column, :direction) do
    def desc? = direction == "desc"
    def sql_direction = desc? ? "DESC" : "ASC"
    def reversed = with(direction: desc? ? "asc" : "desc")
  end

  include Enumerable

  attr_reader :keys

  # columns: the ones the table can be sorted by. default_direction: the direction
  # of a column given without one (a callable taking the column), "asc" if not given.
  def self.from_params(sort, direction, columns:, default_direction: nil)
    directions = direction.is_a?(String) ? direction.split(",").map(&:strip) : []
    names = sort.is_a?(String) ? sort.split(",").map(&:strip) : []

    keys = names.each_with_index.filter_map do |name, index|
      next unless columns.include?(name)

      given = directions[index]
      Key.new(name, DIRECTIONS.include?(given) ? given : (default_direction&.call(name) || "asc"))
    end
    new(keys)
  end

  # keys: Keys, or [column, direction] pairs. A column given twice counts once,
  # where it first appears.
  def initialize(keys = [])
    @keys = keys.map { |key| key.is_a?(Key) ? key : Key.new(*key) }.uniq(&:column).first(MAX_KEYS).freeze
  end

  def each(&) = keys.each(&)
  def empty? = keys.empty?
  def primary = keys.first
  def columns = keys.map(&:column)

  # This order, or the default key alone when it is empty: what the table is
  # actually sorted by, for marking its headings.
  def or(default)
    empty? && default ? self.class.new([ default ]) : self
  end

  # 1 for the first key, 2 for the second, ...; nil for a column not sorted by.
  def rank(column)
    index = columns.index(column)
    index && index + 1
  end

  def key_for(column)
    keys.find { |key| key.column == column }
  end

  # The order after a click on a column's heading. The first key (default is the
  # first key when the order is empty) is reversed; any other column goes first,
  # in direction `first`, and the other keys move down, the last dropping off
  # when there are already MAX_KEYS.
  def clicked(column, first:, default: nil)
    shown = self.or(default)
    if shown.primary&.column == column
      self.class.new([ shown.primary.reversed, *shown.keys.drop(1) ])
    else
      self.class.new([ Key.new(column, first), *keys.reject { |key| key.column == column } ])
    end
  end

  def sort_param = keys.map(&:column).join(",").presence
  def direction_param = keys.map(&:direction).join(",").presence

  # {"sort" => ..., "direction" => ...} for a URL, or {} when empty.
  def to_params
    empty? ? {} : { "sort" => sort_param, "direction" => direction_param }
  end

  def ==(other)
    other.is_a?(SortOrder) && keys == other.keys
  end
end

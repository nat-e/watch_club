defmodule WatchClub.Clubs.LibraryItemsSortOption do
  @values [:added_date, :release_date, :title]
  @sort_by_params Map.new(@values, &{Atom.to_string(&1), &1})

  use Ash.Type.Enum,
    values: @values

  alias WatchClub.Shared.SortOrder

  def default_option, do: :added_date
  def default_order, do: :desc
  def default, do: {default_option(), default_order()}

  def parse_param(sort) when is_nil(sort) or sort == "", do: default()

  def parse_param(sort) when is_binary(sort) do
    with [sort_by_param, sort_order_param] <- String.split(sort, ".", parts: 2),
         {:ok, sort_by} <- Map.fetch(@sort_by_params, sort_by_param),
         {:ok, sort_order} <- SortOrder.parse_param(sort_order_param) do
      {sort_by, sort_order}
    else
      _ -> default()
    end
  end

  def parse_param(_sort), do: default()

  def to_param(sort_by, sort_order), do: "#{sort_by}.#{sort_order}"

  def sort_query(query, :added_date, sort_order) do
    Ash.Query.sort(query, [{:inserted_at, sort_order}])
  end

  def sort_query(query, :release_date, sort_order) do
    Ash.Query.sort(query, [{"content.release_date", SortOrder.nils_last(sort_order)}])
  end

  def sort_query(query, :title, sort_order) do
    Ash.Query.sort(query, [{"content.localized_title_key", SortOrder.nils_last(sort_order)}])
  end

  def sort_query(query, _sort_by, _sort_order), do: query
end

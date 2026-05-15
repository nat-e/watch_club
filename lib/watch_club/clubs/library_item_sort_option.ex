defmodule WatchClub.Clubs.LibraryItemsSortOption do
  use Ash.Type.Enum,
    values: [:added_date, :release_date, :title]

  alias WatchClub.Shared.SortOrder

  def default_option, do: :added_date
  def default_order, do: :desc
  def default, do: {default_option(), default_order()}

  def parse_param(sort) when is_nil(sort) or sort == "", do: default()

  def parse_param(sort) when is_binary(sort) do
    with [sort_by, sort_order] <-
           String.split(sort, ".", parts: 2) |> Enum.map(&String.to_atom/1),
         true <- sort_by in __MODULE__.values(),
         true <- sort_order in SortOrder.values() do
      {sort_by, sort_order}
    else
      e -> IO.inspect(e)
    end
  end

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

defmodule WatchClub.Clubs.Preparations.PrepareLibraryItemsForView do
  @moduledoc """
  Prepares library items for display by applying the requested sort and loading view-ready content.
  """
  use Ash.Resource.Preparation

  alias WatchClub.Clubs.LibraryItemsSortOption
  alias WatchClub.Contents.Content

  @impl true
  def prepare(query, _opts, context) do
    sort_by = Ash.Query.get_argument(query, :sort_by)
    sort_order = Ash.Query.get_argument(query, :sort_order)
    content_for_view_query = Ash.Query.for_read(Content, :for_view, %{}, scope: context)

    query
    |> LibraryItemsSortOption.sort_query(sort_by, sort_order)
    |> Ash.Query.load([:library, content: content_for_view_query], scope: context)
  end
end

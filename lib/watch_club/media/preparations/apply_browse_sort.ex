defmodule WatchClub.Media.Preparations.ApplyBrowseSort do
  @moduledoc """
  Applies the `:sort_by` / `:sort_order` arguments to the browse query,
  appending `id` as a stable tiebreaker for keyset pagination.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    dir = Ash.Query.get_argument(query, :sort_order)

    case Ash.Query.get_argument(query, :sort_by) do
      :imported_at -> Ash.Query.sort(query, inserted_at: dir, id: dir)
      :path -> Ash.Query.sort(query, path: dir, id: dir)
    end
  end
end

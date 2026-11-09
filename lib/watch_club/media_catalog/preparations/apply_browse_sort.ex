defmodule WatchClub.MediaCatalog.Preparations.ApplyBrowseSort do
  @moduledoc """
  Sorts the Media Browser's list by date added, or by title: the title the actor sees, each
  Content's Media together with its TV Show Episodes in order, and the Unmatched Media last in
  both orders, by path.
  """
  use Ash.Resource.Preparation

  require Ash.Sort

  alias WatchClub.Shared.SortOrder

  @impl true
  def prepare(query, _opts, _context) do
    order = Ash.Query.get_argument(query, :sort_order)

    case Ash.Query.get_argument(query, :sort_by) do
      :added ->
        Ash.Query.sort(query, inserted_at: order)

      :title ->
        Ash.Query.sort(query, [
          {Ash.Sort.expr_sort(content.localized_title_key, :string), SortOrder.nils_last(order)},
          {:content_id, order},
          {Ash.Sort.expr_sort(video.tv_show_episode.rank, :integer), order},
          {:path, order}
        ])
    end
  end
end

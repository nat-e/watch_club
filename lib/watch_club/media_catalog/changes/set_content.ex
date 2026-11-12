defmodule WatchClub.MediaCatalog.Changes.SetContent do
  @moduledoc """
  Sets a Media's `content_id` from the Video, Ebook or Audiobook input it's saved with. Pass
  `attachment:`, the name of the action argument holding that input, with atom keys.

  A Video gets the Content of its first Part's Movie, TV Show Episode or Sports Event. A Video
  without Parts gets no Content: it's Unmatched Media.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      content_id =
        case Ash.Changeset.get_argument(changeset, opts[:attachment]) do
          %{parts: [part | _]} -> content_id!(part)
          %{book_id: book_id} -> book_id
          _unmatched_video -> nil
        end

      Ash.Changeset.force_change_attribute(changeset, :content_id, content_id)
    end)
  end

  # Movies and Sports Events share the id of their Content. A TV Show Episode's is its TV Show's.
  defp content_id!(%{movie_id: movie_id}) when is_binary(movie_id), do: movie_id
  defp content_id!(%{sports_event_id: event_id}) when is_binary(event_id), do: event_id

  defp content_id!(%{tv_show_episode_id: episode_id}) when is_binary(episode_id),
    do: Ash.get!(TvShowEpisode, episode_id, authorize?: false).tv_show_id
end

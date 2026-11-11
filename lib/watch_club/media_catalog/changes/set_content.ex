defmodule WatchClub.MediaCatalog.Changes.SetContent do
  @moduledoc """
  Sets the Content of a Media: the Content of the Movie, TV Show Episode or Sports Event its
  Video's first Part belongs to, or of the Book its Ebook or Audiobook is attached to. Movies,
  Sports Events and Books share the id of their Content, and a TV Show Episode belongs to a TV
  Show. A Video without Parts is Unmatched Media, without Content.

  `:attachment` is the action argument holding the Video, Ebook or Audiobook input, with atom keys.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      content_id =
        case Ash.Changeset.get_argument(changeset, opts[:attachment]) do
          %{parts: [part | _]} -> content_id(part)
          %{book_id: book_id} -> book_id
          _unmatched_video -> nil
        end

      Ash.Changeset.force_change_attribute(changeset, :content_id, content_id)
    end)
  end

  defp content_id(%{movie_id: movie_id}) when is_binary(movie_id), do: movie_id
  defp content_id(%{sports_event_id: event_id}) when is_binary(event_id), do: event_id

  defp content_id(%{tv_show_episode_id: episode_id}) when is_binary(episode_id),
    do: Ash.get!(TvShowEpisode, episode_id, authorize?: false).tv_show_id
end

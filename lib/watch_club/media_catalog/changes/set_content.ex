defmodule WatchClub.MediaCatalog.Changes.SetContent do
  @moduledoc """
  Sets the Content of a Media from the Movie, TV Show Episode, Sports Event or Book that its
  Video, Ebook or Audiobook is attached to. Movies, TV Shows, Sports Events and Books share the
  id of their Content. An unmatched Video has a `nil` `movie_id`, `tv_show_episode_id` or
  `sports_event_id`, and its Media has no Content. Any other input crashes.

  `:attachment` is the action argument holding the Video, Ebook or Audiobook input, with atom keys.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      content_id =
        case Ash.Changeset.get_argument(changeset, opts[:attachment]) do
          %{movie_id: movie_id} when not is_nil(movie_id) ->
            movie_id

          %{tv_show_episode_id: episode_id} when not is_nil(episode_id) ->
            Ash.get!(TvShowEpisode, episode_id, authorize?: false).tv_show_id

          %{sports_event_id: sports_event_id} when not is_nil(sports_event_id) ->
            sports_event_id

          %{book_id: book_id} ->
            book_id

          %{movie_id: nil} ->
            nil

          %{tv_show_episode_id: nil} ->
            nil

          %{sports_event_id: nil} ->
            nil
        end

      Ash.Changeset.force_change_attribute(changeset, :content_id, content_id)
    end)
  end
end

defmodule WatchClub.MediaCatalog.Changes.AttachVideo do
  @moduledoc """
  Makes the Video of a Media hold the one Part of its new Content: a Movie file the Movie's, a
  Sports Event file the Sports Event's, a TV Show Episode file the one of the episode of the TV
  Show at the action's `season_number` and `episode_number`. Movies, Sports Events and TV Shows
  share the id of their Content. Without Content, the Video is unmatched and holds no Part.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.MediaCatalog.{Media, Video}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, media ->
      Video
      |> Ash.get!(media.id, authorize?: false)
      |> Ash.update!(%{parts: parts!(media, changeset.arguments)},
        action: :attach,
        authorize?: false
      )

      {:ok, media}
    end)
  end

  defp parts!(%Media{content_id: nil}, _arguments), do: []

  defp parts!(%Media{type: :movie, content_id: movie_id}, _arguments),
    do: [%{movie_id: movie_id, number: 1}]

  defp parts!(%Media{type: :sports_event, content_id: sports_event_id}, _arguments),
    do: [%{sports_event_id: sports_event_id, number: 1}]

  defp parts!(%Media{type: :tv_show_episode, content_id: tv_show_id}, arguments) do
    episode =
      Ash.get!(
        TvShowEpisode,
        %{
          tv_show_id: tv_show_id,
          season_number: arguments.season_number,
          episode_number: arguments.episode_number
        },
        authorize?: false
      )

    [%{tv_show_episode_id: episode.id, number: 1}]
  end
end

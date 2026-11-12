defmodule WatchClub.MediaCatalog.Changes.AttachVideo do
  @moduledoc """
  Links a Media's Video to the Media's Content, which must already be set.

  The Video holds Part 1 of the Movie or Sports Event, or of the TV Show Episode at the action's
  `season_number` and `episode_number`. Without Content, the Video holds no Part.
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

  # Movies, Sports Events and TV Shows share the id of their Content

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

defmodule WatchClub.MediaCatalog.Changes.AttachVideo do
  @moduledoc """
  Attaches the Video of a Media to its new Content: a Movie file to the Movie, a Sports Event file
  to the Sports Event, a TV Show Episode file to the episode of the TV Show at the action's
  `season_number` and `episode_number`. Movies, Sports Events and TV Shows share the id of their
  Content.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.MediaCatalog.{Media, Video}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, media ->
      Video
      |> Ash.get!(media.id, authorize?: false)
      |> Ash.update!(attachment(media, changeset.arguments), action: :attach, authorize?: false)

      {:ok, media}
    end)
  end

  defp attachment(%Media{type: :movie, content_id: movie_id}, _arguments),
    do: %{movie_id: movie_id, tv_show_episode_id: nil, sports_event_id: nil}

  defp attachment(%Media{type: :sports_event, content_id: sports_event_id}, _arguments),
    do: %{movie_id: nil, tv_show_episode_id: nil, sports_event_id: sports_event_id}

  defp attachment(%Media{type: :tv_show_episode, content_id: tv_show_id}, arguments) do
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

    %{movie_id: nil, tv_show_episode_id: episode.id, sports_event_id: nil}
  end
end

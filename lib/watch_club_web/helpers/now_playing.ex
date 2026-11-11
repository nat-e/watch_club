defmodule WatchClubWeb.Helpers.NowPlaying do
  @moduledoc """
  What a Playback Session plays, in words and pictures, for the TV, the TV bar and the Remote.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Contents.{Movie, SportsEvent, TvShowEpisode}
  alias WatchClub.MediaCatalog.Video
  alias WatchClub.Playbacks.Session

  @doc "What to load on a Playback Session to describe what it plays, and its tracks."
  def fields do
    [
      current_playback: [
        media: [
          video: [
            :duration_seconds,
            audio_tracks: [:display_label],
            text_tracks: [:display_label, :language_code, :hls_supported?],
            parts: [
              movie: [:best_localization, :backdrop_path],
              sports_event: [],
              tv_show_episode: [
                :formatted_episode_number,
                :still_path,
                :best_localization,
                tv_show: [:best_localization, :backdrop_path]
              ]
            ]
          ]
        ]
      ]
    ]
  end

  @doc "The Movie's title, the Sports Event's, or the TV Show Episode's."
  def title(%Video{} = video) do
    case Video.work(video) do
      %Movie{} = movie ->
        movie.best_localization.title

      %SportsEvent{} = event ->
        event.title

      %TvShowEpisode{} = episode ->
        (episode.best_localization && episode.best_localization.title) ||
          episode.formatted_episode_number

      nil ->
        dgettext("player", "Video")
    end
  end

  @doc "The TV Show and the episode's number, for a TV Show Episode."
  def subtitle(%Video{} = video) do
    case Video.work(video) do
      %TvShowEpisode{} = episode ->
        "#{episode.tv_show.best_localization.title} · #{episode_numbers(video)}"

      _movie_sports_event_or_unmatched ->
        nil
    end
  end

  @doc """
  The number of the TV Show Episode a Video holds, such as S04E23, or of the first and the last
  for a file holding several: S04E23–E24.
  """
  def episode_numbers(%Video{parts: parts}) do
    first = List.first(parts).tv_show_episode
    last = List.last(parts).tv_show_episode

    cond do
      first.id == last.id ->
        first.formatted_episode_number

      first.season_number == last.season_number ->
        "#{first.formatted_episode_number}–E#{String.pad_leading("#{last.episode_number}", 2, "0")}"

      true ->
        "#{first.formatted_episode_number}–#{last.formatted_episode_number}"
    end
  end

  @doc "The TMDB path of a 16:9 picture of it, or the image URL of a Sports Event's."
  def still_path(%Video{} = video) do
    case Video.work(video) do
      %Movie{} = movie -> movie.backdrop_path
      %SportsEvent{} = event -> event.backdrop_url
      %TvShowEpisode{} = episode -> episode.still_path || episode.tv_show.backdrop_path
      nil -> nil
    end
  end

  @doc "Where the Screen is at now: its last report, plus the time since while it plays."
  def position_now(%Session{paused?: true} = session), do: session.position_seconds

  def position_now(%Session{} = session),
    do:
      session.position_seconds +
        DateTime.diff(DateTime.utc_now(), session.last_heartbeat_at, :millisecond) / 1000

  @doc "The Text Tracks a Screen can show, in the order of the master playlist."
  def text_tracks(%Video{text_tracks: text_tracks}),
    do: Enum.filter(text_tracks, & &1.hls_supported?)
end

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
            movie: [:best_localization, :backdrop_path],
            sports_event: [:best_localization, :backdrop_path],
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
  end

  @doc "The Movie's title, the Sports Event's, or the TV Show Episode's."
  def title(%Video{movie: %Movie{} = movie}), do: movie.best_localization.title
  def title(%Video{sports_event: %SportsEvent{} = event}), do: event.title

  def title(%Video{tv_show_episode: %TvShowEpisode{} = episode}),
    do:
      (episode.best_localization && episode.best_localization.title) ||
        episode.formatted_episode_number

  def title(%Video{}), do: dgettext("player", "Video")

  @doc "The TV Show and the episode's number, for a TV Show Episode."
  def subtitle(%Video{tv_show_episode: %TvShowEpisode{} = episode}),
    do: "#{episode.tv_show.best_localization.title} · #{episode.formatted_episode_number}"

  def subtitle(%Video{}), do: nil

  @doc "The TMDB path of a 16:9 picture of it, or the image URL of a Sports Event's."
  def still_path(%Video{movie: %Movie{} = movie}), do: movie.backdrop_path
  def still_path(%Video{sports_event: %SportsEvent{} = event}), do: event.backdrop_url

  def still_path(%Video{tv_show_episode: %TvShowEpisode{} = episode}),
    do: episode.still_path || episode.tv_show.backdrop_path

  def still_path(%Video{}), do: nil

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

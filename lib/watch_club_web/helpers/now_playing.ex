defmodule WatchClubWeb.Helpers.NowPlaying do
  @moduledoc """
  Titles and pictures describing what a Video plays. Load `fields/0` on a Playback Session, or
  `video_fields/0` on a Video, first.

  When a Video holds only some of its work's Parts, the titles name them: Friends · S06E15 · Part 2.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Contents.{Movie, SportsEvent, TvShowEpisode}
  alias WatchClub.MediaCatalog.{Part, Video}
  alias WatchClub.Playbacks.{Playback, Session}
  alias WatchClubWeb.Helpers.{Parts, PlaybackPaths}

  @doc "What to load on a Playback Session to describe what it plays, and its tracks."
  def fields do
    [
      current_playback: [
        media: [
          video:
            [
              audio_tracks: [:display_label],
              text_tracks: [:display_label, :language_code, :hls_supported?]
            ] ++ video_fields()
        ]
      ]
    ]
  end

  @doc "What to load on a Video before describing it with this module."
  def video_fields do
    [
      :duration_seconds,
      parts: [
        movie: [:best_localization, :backdrop_path, :parts],
        sports_event: [:parts],
        tv_show_episode: [
          :formatted_episode_number,
          :still_path,
          :best_localization,
          :parts,
          tv_show: [:best_localization, :backdrop_path]
        ]
      ]
    ]
  end

  @doc "The main title: the TV Show Episode's title, or the Movie's or Sports Event's with its Parts."
  def title(%Video{} = video) do
    case Video.work(video) do
      %Movie{} = movie ->
        with_part(movie.best_localization.title, video)

      %SportsEvent{} = event ->
        with_part(event.title, video)

      %TvShowEpisode{} = episode ->
        (episode.best_localization && episode.best_localization.title) ||
          episode.formatted_episode_number

      nil ->
        dgettext("player", "Video")
    end
  end

  @doc "The second line of a TV Show Episode, such as Friends · S06E15 · Part 2. Nil otherwise."
  def subtitle(%Video{} = video) do
    case Video.work(video) do
      %TvShowEpisode{} = episode ->
        "#{episode.tv_show.best_localization.title} · #{episode_number(video)}"

      _movie_sports_event_or_unmatched ->
        nil
    end
  end

  @doc """
  The episode number of a Video: S04E23, S04E23–E24 for a file holding two episodes, or
  S04E23 · Part 2. Nil for a Movie or a Sports Event.
  """
  def episode_number(%Video{parts: parts} = video) do
    case {List.first(parts), List.last(parts)} do
      {%Part{tv_show_episode: %TvShowEpisode{} = first}, %Part{tv_show_episode: last}} ->
        with_part(numbers(first, last), video)

      _movie_sports_event_or_unmatched ->
        nil
    end
  end

  defp numbers(%TvShowEpisode{id: id} = episode, %TvShowEpisode{id: id}),
    do: episode.formatted_episode_number

  defp numbers(
         %TvShowEpisode{season_number: season} = first,
         %TvShowEpisode{season_number: season} = last
       ),
       do:
         "#{first.formatted_episode_number}–E#{String.pad_leading("#{last.episode_number}", 2, "0")}"

  defp numbers(first, last),
    do: "#{first.formatted_episode_number}–#{last.formatted_episode_number}"

  # Adds the Parts the Video holds, unless it holds all of its work's Parts
  defp with_part(text, %Video{parts: [first | _] = parts}) do
    work = Part.work(first)
    held = Enum.filter(parts, &(Part.work_id(&1) == work.id))

    if length(held) < length(work.parts),
      do: "#{text} · #{Enum.map_join(held, ", ", &Parts.name/1)}",
      else: text
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

  @doc "The Text Tracks a Screen can show."
  def text_tracks(%Video{text_tracks: text_tracks}),
    do: Enum.filter(text_tracks, & &1.hls_supported?)

  @doc """
  The Text Tracks a Screen can show, with the path of each one's WebVTT file: every Screen loads them
  itself, because the master playlist doesn't list them.
  """
  def text_track_files(%Playback{media: %{video: video}} = playback) do
    Enum.map(
      text_tracks(video),
      &%{
        id: &1.id,
        path: PlaybackPaths.subtitles(playback, &1),
        name: &1.display_label,
        language: &1.language_code
      }
    )
  end
end

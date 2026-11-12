defmodule WatchClub.Markers.Marker.Actions.Detect do
  @moduledoc """
  Finds the Markers of the TV Show Episodes of a season together, or those of a Movie's
  Videos. Each Video gets the Markers of its named chapters. A TV Show Episode missing its
  Intro or Credits gets the longest audio it shares with another episode, searched as
  Jellyfin's Intro Skipper does: each episode is compared with the next ones until one
  shares audio with it.

  A Video whose file can't be read keeps its Markers. Runs ffprobe, ffmpeg and fpcalc
  before the transaction that replaces the Markers of the other Videos.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query
  require Logger

  alias WatchClub.Markers.{AudioFingerprint, Marker, MarkerKind}
  alias WatchClub.MediaCatalog.Video

  @ffprobe Application.compile_env(:watch_club, :ffprobe, WatchClub.Ffmpeg)

  # A chapter is a Marker when each part of its title, such as "Title Sequence" and
  # "Opening Credits" in "2. Title Sequence & Opening Credits", names its kind
  @chapter_titles [
    intro:
      ~r/^(intro|introduction|opening|opening credits?|opening titles|title sequence|main titles?|générique de début|vorspann)$/iu,
    recap: ~r/^(recap|previously|previously on|résumé|récapitulatif)$/iu,
    credits:
      ~r/^(credits?|end credits?|closing credits?|end titles|ending|outro|générique de fin|abspann)$/iu
  ]

  # The part of the Video to compare, and how long the shared audio can be
  @audio_kinds [intro: {:beginning, 10, 120}, credits: {:end, 15, :infinity}]

  @impl true
  def run(input, _opts, context) do
    found =
      input.arguments
      |> videos!(context)
      |> Enum.flat_map(&read_chapter_markers/1)
      |> add_audio_markers()

    {:ok, _result} =
      Ash.transact(Marker, fn ->
        Marker
        |> Ash.Query.filter(video_id in ^Enum.map(found, & &1.video.id))
        |> Ash.bulk_destroy!(:destroy, %{}, scope: context, notify?: true)

        found
        |> Enum.flat_map(fn %{video: video} = reading ->
          Enum.map(
            reading.chapter_markers ++ reading.audio_markers,
            &Map.put(&1, :video_id, video.id)
          )
        end)
        |> Ash.bulk_create!(Marker, :create, scope: context, notify?: true)
      end)

    Enum.each(found, &report/1)
    :ok
  end

  defp videos!(arguments, context) do
    query =
      case arguments do
        %{tv_show_id: tv_show_id, season_number: season_number} ->
          Ash.Query.filter(
            Video,
            exists(
              parts,
              tv_show_episode.tv_show_id == ^tv_show_id and
                tv_show_episode.season_number == ^season_number
            )
          )

        %{movie_id: movie_id} ->
          Ash.Query.filter(Video, exists(parts, movie_id == ^movie_id))
      end

    query
    |> Ash.Query.load([:media, :audio_tracks, parts: [:tv_show_episode]])
    |> Ash.read!(scope: context)
  end

  # The Markers of the Video's named chapters, or nothing when its file can't be read
  defp read_chapter_markers(%Video{media: media} = video) do
    case @ffprobe.probe(media.path) do
      {:ok, metadata} ->
        chapter_markers = metadata |> Map.get("chapters", []) |> markers_of_chapters()
        [%{video: video, chapter_markers: chapter_markers, audio_markers: []}]

      {:error, reason} ->
        log_unreadable(media, reason)
        []
    end
  end

  defp markers_of_chapters(chapters) do
    chapters
    |> Enum.map(&{chapter_kind(&1), &1})
    # Following chapters of one kind make one Marker, and only the first one counts
    |> Enum.chunk_by(fn {kind, _chapter} -> kind end)
    |> Enum.reject(fn [{kind, _chapter} | _] -> is_nil(kind) end)
    |> Enum.uniq_by(fn [{kind, _chapter} | _] -> kind end)
    |> Enum.map(fn [{kind, first} | _] = chapters ->
      {_kind, last} = List.last(chapters)

      %{
        kind: kind,
        start_seconds: String.to_float(first["start_time"]),
        end_seconds: String.to_float(last["end_time"])
      }
    end)
  end

  defp chapter_kind(chapter) do
    parts =
      (get_in(chapter, ["tags", "title"]) || "")
      |> String.replace(~r/^\d+\.\s*/, "")
      |> String.split(~r/\s*(,|&|\band\b)\s*/iu, trim: true)

    Enum.find_value(@chapter_titles, fn {kind, title} ->
      parts != [] and Enum.all?(parts, &Regex.match?(title, &1)) and kind
    end)
  end

  defp log_unreadable(media, reason) do
    Logger.warning("Can't read #{media.path} to find its Markers: #{inspect(reason)}",
      event: :markers_file_unreadable,
      path: media.path
    )
  end

  # Only the audio of TV Show Episodes can be compared
  defp comparable?(%Video{} = video),
    do: episode(video) != nil and video.duration_seconds != nil and video.audio_tracks != []

  # The TV Show Episode of the Video's first Part, which places the Video in its season
  defp episode(%Video{parts: parts}), do: Enum.find_value(parts, & &1.tv_show_episode)

  defp has_marker?(reading, kind), do: Enum.any?(reading.chapter_markers, &(&1.kind == kind))

  # Gives the episodes the Intro and Credits they share. Leaves out the episodes whose audio
  # can't be read.
  defp add_audio_markers(readings) do
    episodes =
      readings
      |> Enum.filter(&comparable?(&1.video))
      |> Enum.sort_by(&{episode(&1.video).episode_number, hd(&1.video.parts).number})

    # Comparing needs two episodes, one of them missing the Marker
    audio_kinds =
      for {kind, _part_and_seconds} = audio_kind <- @audio_kinds,
          match?([_, _ | _], Enum.uniq_by(episodes, &episode(&1.video).id)),
          Enum.any?(episodes, &(not has_marker?(&1, kind))),
          do: audio_kind

    fingerprints =
      for %{video: video} <- episodes,
          {:ok, fingerprints} <- [fingerprints(video, audio_kinds)],
          into: %{},
          do: {video.id, fingerprints}

    fingerprinted = Enum.filter(episodes, &Map.has_key?(fingerprints, &1.video.id))

    shared_ranges =
      for {kind, {part, min_seconds, max_seconds}} <- audio_kinds do
        part_fingerprints = Map.new(fingerprints, fn {id, parts} -> {id, parts[part]} end)
        {kind, longest_shared_ranges(fingerprinted, part_fingerprints, min_seconds, max_seconds)}
      end

    for %{video: video} = reading <- readings,
        not comparable?(video) or Map.has_key?(fingerprints, video.id) do
      audio_markers =
        for {kind, ranges} <- shared_ranges,
            not has_marker?(reading, kind),
            {start_seconds, end_seconds} <- [ranges[video.id]],
            do: %{kind: kind, start_seconds: start_seconds, end_seconds: end_seconds}

      %{reading | audio_markers: audio_markers}
    end
  end

  defp fingerprints(%Video{media: media} = video, audio_kinds) do
    Enum.reduce_while(audio_kinds, {:ok, %{}}, fn {_kind, {part, _, _}}, {:ok, fingerprints} ->
      case AudioFingerprint.fetch(video.id, media.path, video.duration_seconds, part) do
        {:ok, fingerprint} ->
          {:cont, {:ok, Map.put(fingerprints, part, fingerprint)}}

        {:error, reason} ->
          log_unreadable(media, reason)
          {:halt, {:error, reason}}
      end
    end)
  end

  # Intro Skipper's search: compares each episode with the next ones until one shares audio, and
  # keeps the longest shared range. Skips Videos of the same episode: copies share all their audio.
  defp longest_shared_ranges(episodes, fingerprints, min_seconds, max_seconds) do
    episodes
    |> Enum.with_index(1)
    |> Enum.reduce(%{}, fn {%{video: video}, next}, longest ->
      episodes
      |> Enum.drop(next)
      |> Enum.reject(&(episode(&1.video).id == episode(video).id))
      |> Enum.find_value(longest, fn %{video: other} ->
        with {range, other_range} <-
               AudioFingerprint.shared_range(
                 fingerprints[video.id],
                 fingerprints[other.id],
                 min_seconds,
                 max_seconds
               ) do
          longest |> keep_longer(video.id, range) |> keep_longer(other.id, other_range)
        end
      end)
    end)
  end

  defp keep_longer(longest, video_id, {start_seconds, end_seconds} = range) do
    Map.update(longest, video_id, range, fn {kept_start, kept_end} = kept ->
      if end_seconds - start_seconds > kept_end - kept_start, do: range, else: kept
    end)
  end

  # One count for each kind, by where it came from, and a log line with the same
  defp report(%{video: video} = reading) do
    sources =
      for kind <- MarkerKind.values() do
        source =
          cond do
            Enum.any?(reading.chapter_markers, &(&1.kind == kind)) -> :chapter
            Enum.any?(reading.audio_markers, &(&1.kind == kind)) -> :audio
            true -> :none
          end

        :telemetry.execute([:watch_club, :marker_detection, :marker], %{count: 1}, %{
          media_type: video.media.type,
          kind: kind,
          source: source
        })

        {kind, source}
      end

    found = for {kind, source} <- sources, source != :none, do: "#{kind} from #{source}"

    Logger.info(
      "Found the Markers of #{video.media.path}: #{if found == [], do: "none", else: Enum.join(found, ", ")}",
      event: :markers_detected,
      path: video.media.path
    )
  end
end

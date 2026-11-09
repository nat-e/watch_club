defmodule WatchClub.Markers.Marker.Actions.Detect do
  @moduledoc """
  Finds the Video's Markers from its named chapters. A TV Show Episode missing
  its Intro or Credits also gets them from the audio it shares with the nearest
  episodes of its TV Show, which then get the Marker they lack too.

  Runs ffprobe, ffmpeg and fpcalc before the transaction that replaces the
  Video's Markers.
  """

  use Ash.Resource.Actions.Implementation

  import Ash.Expr

  require Ash.Query
  require Logger

  alias WatchClub.Contents.TvShowEpisode
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
  @compared_episodes 3

  @impl true
  def run(input, _opts, context) do
    video =
      Ash.load!(input.arguments.video, [:media, :audio_tracks, tv_show_episode: [:rank]],
        scope: context
      )

    chapter_markers = chapter_markers!(video)
    {markers, markers_of_others} = add_audio_markers!(chapter_markers, video, context)
    report(video, chapter_markers, markers)

    {:ok, _result} =
      Ash.transact(Marker, fn ->
        Marker
        |> Ash.Query.filter(video_id == ^video.id)
        |> Ash.bulk_destroy!(:destroy, %{}, scope: context, notify?: true)

        markers
        |> Enum.map(&Map.put(&1, :video_id, video.id))
        |> Ash.bulk_create!(Marker, :create, scope: context, notify?: true)

        Ash.bulk_create!(markers_of_others, Marker, :add_if_missing,
          scope: context,
          notify?: true
        )
      end)

    :ok
  end

  # One count for each kind, by where it came from, and a log line with the same
  defp report(video, chapter_markers, markers) do
    sources =
      for kind <- MarkerKind.values() do
        source =
          cond do
            Enum.any?(chapter_markers, &(&1.kind == kind)) -> :chapter
            Enum.any?(markers, &(&1.kind == kind)) -> :audio
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

  defp chapter_markers!(%Video{media: media}) do
    {:ok, metadata} = @ffprobe.probe(media.path)

    metadata
    |> Map.get("chapters", [])
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

  # Only the audio of a TV Show Episode can be compared with other episodes
  defp add_audio_markers!(markers, %Video{} = video, _context)
       when is_nil(video.tv_show_episode) or is_nil(video.duration_seconds) or
              video.audio_tracks == [],
       do: {markers, []}

  defp add_audio_markers!(markers, video, context) do
    missing =
      Enum.reject(@audio_kinds, fn {kind, _} -> Enum.any?(markers, &(&1.kind == kind)) end)

    others = if missing == [], do: [], else: nearest_episode_videos!(video, context)

    for {kind, {part, min_seconds, max_seconds}} <- missing,
        others != [],
        reduce: {markers, []} do
      {markers, markers_of_others} ->
        own = fingerprint!(video, part)

        Enum.find_value(others, fn other ->
          theirs = fingerprint!(other, part)

          with {range, other_range} <-
                 AudioFingerprint.shared_range(own, theirs, min_seconds, max_seconds) do
            {other, range, other_range}
          end
        end)
        |> case do
          nil ->
            {markers, markers_of_others}

          {other, {start_seconds, end_seconds}, {other_start_seconds, other_end_seconds}} ->
            {[%{kind: kind, start_seconds: start_seconds, end_seconds: end_seconds} | markers],
             [
               %{
                 video_id: other.id,
                 kind: kind,
                 start_seconds: other_start_seconds,
                 end_seconds: other_end_seconds
               }
               | markers_of_others
             ]}
        end
    end
  end

  # A Video of each of the nearest other episodes of the TV Show, the same season first
  defp nearest_episode_videos!(%Video{tv_show_episode: episode}, context) do
    distance =
      calc(
        if(rank > ^episode.rank, do: rank - ^episode.rank, else: ^episode.rank - rank),
        type: :integer
      )

    with_audio =
      Video
      |> Ash.Query.filter(not is_nil(duration_seconds) and exists(audio_tracks, true))
      |> Ash.Query.sort(:id)
      |> Ash.Query.load(:media)

    TvShowEpisode
    |> Ash.Query.filter(
      tv_show_id == ^episode.tv_show_id and id != ^episode.id and
        exists(videos, not is_nil(duration_seconds) and exists(audio_tracks, true))
    )
    |> Ash.Query.sort([{distance, :asc}, rank: :asc])
    |> Ash.Query.limit(@compared_episodes)
    |> Ash.Query.load(videos: with_audio)
    |> Ash.read!(scope: context)
    |> Enum.map(&hd(&1.videos))
  end

  defp fingerprint!(video, part),
    do: AudioFingerprint.fetch!(video.id, video.media.path, video.duration_seconds, part)
end

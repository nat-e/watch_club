defmodule WatchClub.MediaCatalog.Video.Changes.DetectMarkers do
  @moduledoc """
  Finds the Video's Markers from its named chapters. A TV Show Episode missing
  its Intro or Credits also gets them from the audio it shares with the nearest
  episodes of its TV Show, which then get the Marker they lack too.

  Runs ffprobe, ffmpeg and fpcalc before the transaction. Two detections must not
  run at once: they could give the same episode the same Marker.
  """

  use Ash.Resource.Change

  import Ash.Expr

  require Ash.Query

  alias WatchClub.Ffmpeg.AudioFingerprint
  alias WatchClub.MediaCatalog.{Marker, Video}

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
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      video = Ash.load!(changeset.data, [:media, tv_show_episode: [:rank]], scope: context)
      # The file may have changed since its fingerprints were cached
      AudioFingerprint.delete!(video.id)

      {markers, markers_of_others} =
        video |> chapter_markers() |> add_audio_markers(video, context)

      changeset
      |> Ash.Changeset.manage_relationship(:markers, markers,
        on_no_match: :create,
        on_missing: :destroy
      )
      |> Ash.Changeset.after_action(fn _changeset, video ->
        Ash.bulk_create!(markers_of_others, Marker, :create, scope: context)
        {:ok, video}
      end)
    end)
  end

  defp chapter_markers(%Video{media: media}) do
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

  defp add_audio_markers(markers, %Video{tv_show_episode: nil}, _context), do: {markers, []}
  defp add_audio_markers(markers, %Video{duration_seconds: nil}, _context), do: {markers, []}

  defp add_audio_markers(markers, video, context) do
    missing =
      Enum.reject(@audio_kinds, fn {kind, _} -> Enum.any?(markers, &(&1.kind == kind)) end)

    episodes = if missing == [], do: [], else: nearest_episodes(video, context)

    for {kind, {part, min_seconds, max_seconds}} <- missing,
        episodes != [],
        reduce: {markers, []} do
      {markers, markers_of_others} ->
        own = fingerprint!(video, part)

        Enum.find_value(episodes, fn other ->
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
            marker = %{kind: kind, start_seconds: start_seconds, end_seconds: end_seconds}

            marker_of_other = %{
              video_id: other.id,
              kind: kind,
              start_seconds: other_start_seconds,
              end_seconds: other_end_seconds
            }

            if Enum.any?(other.markers, &(&1.kind == kind)),
              do: {[marker | markers], markers_of_others},
              else: {[marker | markers], [marker_of_other | markers_of_others]}
        end
    end
  end

  # Videos of other episodes of the TV Show, the same season first
  defp nearest_episodes(%Video{tv_show_episode: episode}, context) do
    distance =
      calc(
        if(tv_show_episode.rank > ^episode.rank,
          do: tv_show_episode.rank - ^episode.rank,
          else: ^episode.rank - tv_show_episode.rank
        ),
        type: :integer
      )

    Video
    |> Ash.Query.filter(
      tv_show_episode.tv_show_id == ^episode.tv_show_id and
        tv_show_episode_id != ^episode.id and not is_nil(duration_seconds)
    )
    |> Ash.Query.sort([{distance, :asc}])
    |> Ash.Query.limit(@compared_episodes)
    |> Ash.Query.load([:media, :markers])
    |> Ash.read!(scope: context)
  end

  defp fingerprint!(video, part),
    do: AudioFingerprint.fetch!(video.id, video.media.path, video.duration_seconds, part)
end

defmodule WatchClub.MediaSources.Import.Ingestor.ExtractStructure.Sidecars do
  @moduledoc """
  Internal helper for `ExtractStructure`. Discovers sidecar subtitle files
  alongside a video candidate and appends them to its `MediaStructure.text_tracks`.
  `TextTracks` then reads their language and markers from their titles.

  `FileStamp` lists them too, so a new, changed or removed sidecar changes the video's File Stamp.
  """

  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MediaStructure.TextTrack
  alias WatchClub.Shared.Path, as: Paths

  @subtitle_extensions MapSet.new([".ass", ".srt", ".ssa", ".sub", ".vtt"])

  def append(%Candidate{} = candidate) do
    video_basename = Path.basename(candidate.path, Path.extname(candidate.path))

    sidecars =
      for path <- paths(candidate.path) do
        extension = path |> Path.extname() |> String.downcase()
        subtitle_basename = Path.basename(path, Path.extname(path))
        suffix = String.replace_prefix(subtitle_basename, video_basename, "")

        %TextTrack{sidecar_path: path, codec: codec_for_extension(extension)}
        |> struct!(parse_suffix(suffix))
      end

    structure = candidate.media_structure
    %{candidate | media_structure: %{structure | text_tracks: structure.text_tracks ++ sidecars}}
  end

  @doc "The normalized paths of the subtitle files next to the video at `video_path`, sorted."
  def paths(video_path) do
    directory = Path.dirname(video_path)
    video_basename = Path.basename(video_path, Path.extname(video_path))

    case File.ls(directory) do
      {:ok, entries} ->
        for entry <- Enum.sort(entries),
            path = Path.join(directory, entry),
            sidecar?(path, video_basename),
            do: Paths.normalize(path)

      {:error, _reason} ->
        []
    end
  end

  defp sidecar?(path, video_basename) do
    extension = path |> Path.extname() |> String.downcase()

    not String.starts_with?(Path.basename(path), ".") and
      MapSet.member?(@subtitle_extensions, extension) and
      matching_sidecar?(Path.basename(path, Path.extname(path)), video_basename) and
      match?({:ok, %{type: :regular}}, File.lstat(path))
  end

  defp matching_sidecar?(subtitle_basename, video_basename) do
    String.downcase(subtitle_basename) == String.downcase(video_basename) or
      String.starts_with?(
        String.downcase(subtitle_basename),
        String.downcase(video_basename) <> "."
      )
  end

  # The words after the video's name, such as `.en.hi` or `.fr-CA.forced`, are its title, from
  # which `TextTracks` reads its language, region and markers
  defp parse_suffix(suffix) do
    {default, words} =
      suffix
      |> String.split(".", trim: true)
      |> Enum.split_with(&(String.downcase(&1) == "default"))

    %{title: if(words != [], do: Enum.join(words, " ")), default?: default != []}
  end

  defp codec_for_extension(".ass"), do: "ass"
  defp codec_for_extension(".srt"), do: "subrip"
  defp codec_for_extension(".ssa"), do: "ssa"
  defp codec_for_extension(".sub"), do: "sub"
  defp codec_for_extension(".vtt"), do: "webvtt"
end

defmodule WatchClub.MediaSources.Import.Ingestor.ExtractStructure.Sidecars do
  @moduledoc """
  Internal helper for `ExtractStructure`. Discovers sidecar subtitle files
  alongside a video candidate and appends them to its `MediaStructure.text_tracks`.
  `TextTracks` then reads their language and markers from their titles.

  Only called from the video branch of `ExtractStructure`; never called from
  the pipeline orchestrator.
  """

  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MediaStructure.TextTrack
  alias WatchClub.Shared.Path, as: Paths

  @subtitle_extensions MapSet.new([".ass", ".srt", ".ssa", ".sub", ".vtt"])

  def append(%Candidate{} = candidate) do
    sidecars = discover(candidate)
    structure = candidate.media_structure
    %{candidate | media_structure: %{structure | text_tracks: structure.text_tracks ++ sidecars}}
  end

  defp discover(candidate) do
    directory = Path.dirname(candidate.path)
    video_basename = Path.basename(candidate.path, Path.extname(candidate.path))

    case File.ls(directory) do
      {:ok, entries} ->
        entries
        |> Enum.sort()
        |> Enum.flat_map(fn entry ->
          directory
          |> Path.join(entry)
          |> sidecar_text_track(video_basename)
        end)

      {:error, _reason} ->
        []
    end
  end

  defp sidecar_text_track(path, video_basename) do
    extension = path |> Path.extname() |> String.downcase()
    basename = Path.basename(path)
    subtitle_basename = Path.basename(path, Path.extname(path))

    with false <- String.starts_with?(basename, "."),
         true <- MapSet.member?(@subtitle_extensions, extension),
         true <- matching_sidecar?(subtitle_basename, video_basename),
         {:ok, %{type: :regular}} <- File.lstat(path) do
      suffix = String.replace_prefix(subtitle_basename, video_basename, "")

      [
        %TextTrack{
          sidecar_path: Paths.normalize(path),
          codec: codec_for_extension(extension)
        }
        |> struct!(parse_suffix(suffix))
      ]
    else
      _ -> []
    end
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

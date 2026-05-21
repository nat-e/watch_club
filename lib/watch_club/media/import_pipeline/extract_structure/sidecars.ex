defmodule WatchClub.Media.ImportPipeline.ExtractStructure.Sidecars do
  @moduledoc """
  Internal helper for `ExtractStructure`. Discovers sidecar subtitle files
  alongside a video candidate and appends them to its `MediaStructure.text_tracks`.

  Only called from the video branch of `ExtractStructure`; never called from
  the pipeline orchestrator.
  """

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.MediaStructure.TextTrack

  @subtitle_extensions MapSet.new([".ass", ".srt", ".ssa", ".sub", ".vtt"])

  @language_codes %{
    "ar" => "ara",
    "ara" => "ara",
    "de" => "deu",
    "deu" => "deu",
    "ger" => "deu",
    "en" => "eng",
    "eng" => "eng",
    "es" => "spa",
    "spa" => "spa",
    "fr" => "fra",
    "fra" => "fra",
    "fre" => "fra",
    "hi" => "hin",
    "hin" => "hin",
    "it" => "ita",
    "ita" => "ita",
    "ja" => "jpn",
    "jpn" => "jpn",
    "ko" => "kor",
    "kor" => "kor",
    "nl" => "nld",
    "nld" => "nld",
    "dut" => "nld",
    "pt" => "por",
    "por" => "por",
    "ru" => "rus",
    "rus" => "rus",
    "zh" => "zho",
    "zho" => "zho",
    "chi" => "zho"
  }

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
      parsed = parse_suffix(suffix)

      [
        %TextTrack{
          sidecar_path: Path.expand(path),
          codec: codec_for_extension(extension),
          language: parsed.language,
          title: parsed.title,
          default?: parsed.default?,
          forced?: parsed.forced?,
          hearing_impaired?: parsed.hearing_impaired?
        }
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

  defp parse_suffix(""), do: empty_suffix()

  defp parse_suffix(suffix) do
    suffix
    |> String.trim_leading(".")
    |> String.split(".", trim: true)
    |> Enum.reverse()
    |> Enum.reduce(empty_suffix(), fn token, acc ->
      parse_token(token, acc)
    end)
    |> Map.update!(:title_tokens, &Enum.reverse/1)
    |> title_from_tokens()
  end

  defp empty_suffix do
    %{
      language: nil,
      title: nil,
      title_tokens: [],
      default?: false,
      forced?: false,
      hearing_impaired?: false
    }
  end

  defp parse_token(token, acc) do
    normalized = token |> String.downcase() |> String.trim()

    cond do
      String.contains?(normalized, "default") ->
        %{acc | default?: true}

      String.contains?(normalized, "forced") or String.contains?(normalized, "foreign") ->
        %{acc | forced?: true}

      normalized in ["cc", "sdh"] ->
        %{acc | hearing_impaired?: true}

      normalized == "hi" and is_nil(acc.language) ->
        %{acc | language: "hin", hearing_impaired?: true}

      language = language_code(normalized) ->
        if is_nil(acc.language) do
          %{acc | language: language}
        else
          %{acc | title_tokens: [token | acc.title_tokens]}
        end

      true ->
        %{acc | title_tokens: [token | acc.title_tokens]}
    end
  end

  defp language_code(token) do
    token
    |> String.split("-", parts: 2)
    |> List.first()
    |> then(&Map.get(@language_codes, &1))
  end

  defp title_from_tokens(%{title_tokens: []} = parsed), do: Map.delete(parsed, :title_tokens)

  defp title_from_tokens(parsed) do
    title =
      parsed.title_tokens
      |> Enum.join(" ")
      |> String.trim()

    parsed
    |> Map.put(:title, title)
    |> Map.delete(:title_tokens)
  end

  defp codec_for_extension(".ass"), do: "ass"
  defp codec_for_extension(".srt"), do: "subrip"
  defp codec_for_extension(".ssa"), do: "ssa"
  defp codec_for_extension(".sub"), do: "sub"
  defp codec_for_extension(".vtt"), do: "webvtt"
end

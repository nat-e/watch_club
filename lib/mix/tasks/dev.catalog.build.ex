defmodule Mix.Tasks.Dev.Catalog.Build do
  @shortdoc "Builds the missing files of the dev catalog from their free-licensed sources"
  @moduledoc """
  Builds each file listed in `dev/catalog/manifest/*.exs` that `dev/catalog/media/` doesn't
  have yet, then rewrites `dev/catalog/ATTRIBUTION.md`. Existing files are kept, because Git
  LFS keeps every version of a file forever: delete a file to build it again.

      mix dev.catalog.build                 # every missing file
      mix dev.catalog.build Sintel          # the missing files whose path contains "Sintel"

  ffmpeg reads only the clip it needs from each remote source.

  ## Manifests

  Each manifest returns `%{sources: sources, files: files}`. A source is a free-licensed work:

      coffee_run: %{
        title: "Coffee Run",
        author: "Blender Studio",
        license: "CC BY 4.0",
        license_url: "https://creativecommons.org/licenses/by/4.0/",
        page_url: "https://commons.wikimedia.org/wiki/File:…",  # where its license is stated
        video_url: "https://upload.wikimedia.org/…720p.vp9.webm",
        subtitle_urls: %{eng: "…", fre: "…"}                       # optional
      }

  A file is cut from a source, from one or more `{start, duration}` clips in seconds:

      %{
        path: "movies/Coffee Run (2020) {tmdb-717986}/Coffee Run (2020).mkv",
        source: :coffee_run,
        clips: [{60, 120}],
        height: 720,                         # optional, 720 by default
        codec: :h264,                        # optional, :hevc by default
        music: :gymnopedie,                  # optional, replaces the audio with this source's
        subtitles: [eng: [], fre: [:forced]],  # optional, embedded, with their flags
        sidecars: [eng: [], fre: [:forced]],   # optional, next to the file: name.fr.forced.srt
        chapters: [{0, "Intro"}, {25, "Chapter 1"}],  # optional, starts in seconds
        ffmpeg: [...]                        # optional, encoding arguments that replace the default
      }

  `ffmpeg` arguments come after the inputs, in this order: the clips, then the subtitles, then
  the music, then the chapters. Without them, a file is encoded in HEVC or H.264 and stereo
  AAC, with its embedded subtitles in SRT, or `mov_text` in MP4.
  """
  use Mix.Task

  @catalog "dev/catalog"
  @cache "tmp/dev_catalog"
  @user_agent "WatchClubDevCatalog/1.0 (https://github.com/nat-e/watch_club)"
  @reconnect ["-reconnect", "1", "-reconnect_on_network_error", "1", "-reconnect_delay_max", "10"]
  # ISO 639-2 codes in metadata, ISO 639-1 codes in sidecar file names
  @two_letter_codes %{
    ara: "ar",
    chi: "zh",
    dut: "nl",
    eng: "en",
    fre: "fr",
    ger: "de",
    ita: "it",
    jpn: "ja",
    kor: "ko",
    pol: "pl",
    por: "pt",
    rus: "ru",
    spa: "es",
    swe: "sv"
  }

  @impl true
  def run(args) do
    {:ok, _apps} = Application.ensure_all_started(:req)
    %{sources: sources, files: files} = read_manifests!()
    filter = List.first(args, "")

    for file <- files, String.contains?(file.path, filter) do
      output = Path.join([@catalog, "media", file.path])

      if File.exists?(output) do
        Mix.shell().info("Keep #{file.path}")
      else
        Mix.shell().info("Build #{file.path}")
        build!(file, Map.fetch!(sources, file.source), sources, output)
      end
    end

    write_attribution!(sources, files)
  end

  defp read_manifests! do
    Path.join([@catalog, "manifest", "*.exs"])
    |> Path.wildcard()
    |> Enum.map(fn path -> path |> Code.eval_file() |> elem(0) end)
    |> Enum.reduce(%{sources: %{}, files: []}, fn manifest, acc ->
      %{
        sources:
          Map.merge(acc.sources, manifest.sources, fn key, _, _ ->
            Mix.raise("Source #{key} is listed twice")
          end),
        files: acc.files ++ manifest.files
      }
    end)
  end

  defp build!(file, source, sources, output) do
    File.mkdir_p!(Path.dirname(output))
    tmp_output = Path.join(Path.dirname(output), ".building-" <> Path.basename(output))

    clip_inputs =
      Enum.flat_map(file.clips, fn {start, duration} ->
        ["-ss", to_string(start), "-t", to_string(duration)] ++
          @reconnect ++ ["-i", source.video_url]
      end)

    {first_start, _duration} = hd(file.clips)
    total_duration = file.clips |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    # Subtitles are cut like the first clip, so they stay in sync
    subtitles = Map.get(file, :subtitles, [])

    subtitle_inputs =
      Enum.flat_map(subtitles, fn {language, _flags} ->
        path = cached_subtitle!(source, language)
        ["-ss", to_string(first_start), "-t", to_string(total_duration), "-i", path]
      end)

    music_inputs =
      case Map.get(file, :music) do
        nil ->
          []

        key ->
          ["-stream_loop", "-1", "-t", to_string(total_duration), "-i", sources[key].audio_url]
      end

    chapters_inputs =
      case Map.get(file, :chapters) do
        nil -> []
        chapters -> ["-i", chapters_metadata!(chapters, total_duration)]
      end

    arguments =
      ["-hide_banner", "-loglevel", "error", "-y", "-user_agent", @user_agent] ++
        clip_inputs ++
        subtitle_inputs ++
        music_inputs ++
        chapters_inputs ++
        Map.get_lazy(file, :ffmpeg, fn -> default_encoding(file, output) end) ++
        chapters_arguments(file) ++ ["-t", to_string(total_duration), tmp_output]

    case System.cmd("ffmpeg", arguments, stderr_to_stdout: true) do
      {_output, 0} -> File.rename!(tmp_output, output)
      {log, status} -> Mix.raise("ffmpeg exited with #{status} for #{file.path}:\n#{log}")
    end

    for {language, flags} <- Map.get(file, :sidecars, []) do
      write_sidecar!(source, language, flags, first_start, total_duration, output)
    end
  end

  defp default_encoding(file, output) do
    clip_count = length(file.clips)
    subtitles = Map.get(file, :subtitles, [])
    music_index = if Map.has_key?(file, :music), do: clip_count + length(subtitles)
    height = Map.get(file, :height, 720)

    {media_maps, filter} =
      if clip_count == 1 do
        audio = if music_index, do: "#{music_index}:a:0", else: "0:a:0?"
        {["-map", "[v]", "-map", audio], "[0:v:0]scale=-2:#{height},format=yuv420p[v]"}
      else
        pads = Enum.map_join(0..(clip_count - 1), fn index -> "[#{index}:v:0][#{index}:a:0]" end)

        {["-map", "[v]", "-map", "[a]"],
         "#{pads}concat=n=#{clip_count}:v=1:a=1[vc][a];[vc]scale=-2:#{height},format=yuv420p[v]"}
      end

    subtitle_maps =
      subtitles
      |> Enum.with_index(clip_count)
      |> Enum.flat_map(fn {{language, flags}, input} ->
        index = input - clip_count

        [
          "-map",
          "#{input}:s:0",
          "-metadata:s:s:#{index}",
          "language=#{language}",
          "-disposition:s:#{index}",
          disposition(flags)
        ]
      end)

    subtitle_codec = if Path.extname(output) == ".mp4", do: "mov_text", else: "srt"

    video_codec =
      case Map.get(file, :codec, :hevc) do
        :hevc ->
          ["-c:v", "libx265", "-crf", "30", "-tag:v", "hvc1", "-x265-params", "log-level=error"]

        :h264 ->
          ["-c:v", "libx264", "-preset", "slow", "-crf", "28"]
      end

    ["-filter_complex", filter] ++
      media_maps ++
      subtitle_maps ++
      video_codec ++
      ["-c:a", "aac", "-b:a", "128k", "-ac", "2", "-c:s", subtitle_codec]
  end

  defp disposition([]), do: "0"
  defp disposition(flags), do: Enum.map_join(flags, "+", &to_string/1)

  defp chapters_arguments(%{chapters: _chapters} = file) do
    input = length(file.clips) + length(Map.get(file, :subtitles, [])) + music_count(file)
    ["-map_metadata", to_string(input), "-map_chapters", to_string(input)]
  end

  defp chapters_arguments(_file), do: []

  defp music_count(file), do: if(Map.has_key?(file, :music), do: 1, else: 0)

  defp chapters_metadata!(chapters, total_duration) do
    ends = chapters |> Enum.drop(1) |> Enum.map(&elem(&1, 0)) |> Kernel.++([total_duration])

    content =
      chapters
      |> Enum.zip(ends)
      |> Enum.map_join(fn {{start, title}, ending} ->
        "[CHAPTER]\nTIMEBASE=1/1000\nSTART=#{start * 1000}\nEND=#{ending * 1000}\ntitle=#{title}\n"
      end)

    path = Path.join(@cache, "chapters-#{:erlang.phash2(chapters)}.txt")
    File.mkdir_p!(@cache)
    File.write!(path, ";FFMETADATA1\n" <> content)
    path
  end

  defp write_sidecar!(source, language, flags, start, duration, output) do
    suffix = Enum.map_join([Map.fetch!(@two_letter_codes, language) | flags], ".", &to_string/1)
    path = Path.rootname(output) <> ".#{suffix}.srt"

    arguments =
      ["-hide_banner", "-loglevel", "error", "-y"] ++
        ["-ss", to_string(start), "-t", to_string(duration)] ++
        ["-i", cached_subtitle!(source, language), "-c:s", "srt", path]

    {_output, 0} = System.cmd("ffmpeg", arguments, stderr_to_stdout: true)
  end

  defp cached_subtitle!(source, language) do
    url = source.subtitle_urls |> Map.fetch!(language)
    path = Path.join([@cache, "subtitles", "#{:erlang.phash2(url)}.srt"])

    unless File.exists?(path) do
      File.mkdir_p!(Path.dirname(path))

      %{status: 200, body: body} =
        Req.get!(url, headers: [user_agent: @user_agent], decode_body: false)

      File.write!(path, body)
    end

    path
  end

  defp write_attribution!(sources, files) do
    rows =
      files
      |> Enum.group_by(& &1.source)
      |> Enum.sort_by(fn {key, _files} -> String.downcase(sources[key].title) end)
      |> Enum.map_join("\n", fn {key, source_files} ->
        source = sources[key]
        paths = Enum.map_join(source_files, "<br>", &"`#{&1.path}`")

        "| [#{source.title}](#{source.page_url}) | #{source.author} | " <>
          "[#{source.license}](#{source.license_url}) | #{paths} |"
      end)

    music_rows =
      files
      |> Enum.map(&Map.get(&1, :music))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.map_join("\n", fn key ->
        source = sources[key]

        "| [#{source.title}](#{source.page_url}) | #{source.author} | " <>
          "[#{source.license}](#{source.license_url}) |"
      end)

    File.write!(Path.join(@catalog, "ATTRIBUTION.md"), """
    # Attribution

    Generated by `mix dev.catalog.build` from `manifest/`. Each file in `media/` is a clip of
    the work it is listed with, cut, scaled and re-encoded, and some have subtitles, chapters or
    music added. Each file keeps the license of its work: files cut from a CC BY-SA work are
    under CC BY-SA too.

    | Work | Author | License | Files |
    | --- | --- | --- | --- |
    #{rows}

    ## Music added to silent films

    | Work | Author | License |
    | --- | --- | --- |
    #{music_rows}
    """)
  end
end

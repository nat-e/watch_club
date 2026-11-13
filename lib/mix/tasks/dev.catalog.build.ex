defmodule Mix.Tasks.Dev.Catalog.Build do
  @shortdoc "Builds the missing files of the dev catalog from their free-licensed sources"
  @moduledoc """
  Builds each file listed in `dev/catalog/manifest/*.exs` that `dev/catalog/media/` doesn't
  have yet, then rewrites `dev/catalog/ATTRIBUTION.md`. Existing files are kept, because Git
  LFS keeps every version of a file forever: delete a file to build it again.

      mix dev.catalog.build                 # every missing file
      mix dev.catalog.build Sintel          # the missing files whose path contains "Sintel"

  ffmpeg downloads each clip of a remote source once, with a margin, to `tmp/dev_catalog/clips`,
  and music and subtitles are downloaded whole.
  Picture subtitles also need `seconv`, Subtitle Edit's command line, and Dolby Vision needs
  `dovi_tool` and `mkvmerge`.

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

  A music source has an `audio_url` instead, and a font a `font_url` and its `font_family`.
  Sources with the same `page_url` are one work in the attribution.

  A file is cut from a source, from one or more `{start, duration}` clips in seconds, played
  one after the other. A clip can come from another source, as `{other_source, start, duration}`:

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
        input_options: ["-noautorotate"],    # optional, ffmpeg options of each clip
        inputs: [other_source: {60, 120}],   # optional, a clip of another source's video
        font: :some_font,                    # optional, attached, and used by ASS subtitles
        dolby_vision: %{…},                  # optional, see below
        ffmpeg: [...]                        # optional, encoding arguments that replace the default
      }

  Flags can also set a subtitle's `format`, such as `subtitles: [eng: [:default, format: :pgs]]`.
  Embedded subtitles are `:srt` by default, `:ass`, or pictures rendered by `seconv`: `:pgs` in
  1920x1080 or `:vobsub` in 720x480. Sidecars are `:srt` or `:vtt`, and `charset:
  "WINDOWS-1252"` re-encodes one from UTF-8.

  `ffmpeg` arguments map and encode the video and audio of the inputs, which come in this
  order: the clips, then the subtitles, then the music, then the chapters, then the other
  inputs. Without them, a file is encoded in HEVC or H.264 and stereo AAC. The embedded
  subtitles are added after them, with their language and flags, in their format, or in
  `mov_text` in MP4, M4V and MOV, and in WebVTT in WebM.

  `dolby_vision` takes the Level 6 metadata of a Dolby Vision profile 8.1 RPU, such as
  `%{max_display_mastering_luminance: 1000, min_display_mastering_luminance: 1,
  max_content_light_level: 1000, max_frame_average_light_level: 400}`. Every frame of the file,
  an MKV of HDR10 HEVC, gets the same RPU.
  """
  use Mix.Task

  @catalog "dev/catalog"
  @cache "tmp/dev_catalog"
  @user_agent "WatchClubDevCatalog/1.0 (https://github.com/nat-e/watch_club)"
  @reconnect [
    "-reconnect",
    "1",
    "-reconnect_on_network_error",
    "1",
    "-reconnect_on_http_error",
    "429,5xx",
    "-reconnect_delay_max",
    "10"
  ]
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
        build!(file, sources, output)
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

  defp build!(file, sources, output) do
    File.mkdir_p!(Path.dirname(output))

    # Each build writes its own file, so that two builds of a file can't mix their writes
    tmp_name = "#{:erlang.phash2(output)}-#{System.pid()}#{Path.extname(output)}"
    tmp_output = Path.join([@cache, "building", tmp_name])

    File.mkdir_p!(Path.dirname(tmp_output))
    source = Map.fetch!(sources, file.source)
    input_options = Map.get(file, :input_options, [])

    clips =
      Enum.map(file.clips, fn
        {start, duration} -> {source.video_url, {start, duration}}
        {key, start, duration} -> {Map.fetch!(sources, key).video_url, {start, duration}}
      end)

    clip_inputs =
      Enum.flat_map(clips, fn {url, clip} -> input_options ++ remote_clip(url, clip) end)

    [{_url, {first_start, _duration}} | _clips] = clips

    total_duration =
      clips |> Enum.map(fn {_url, {_start, duration}} -> duration end) |> Enum.sum()

    # Subtitles are cut like the first clip, so they stay in sync
    subtitle_inputs =
      Enum.flat_map(Map.get(file, :subtitles, []), fn {language, flags} ->
        subtitle_input!(file, sources, language, flags, first_start, total_duration)
      end)

    music_inputs =
      case Map.get(file, :music) do
        nil -> []
        key -> ["-stream_loop", "-1", "-t", to_string(total_duration), "-i", music!(sources[key])]
      end

    chapters_inputs =
      case Map.get(file, :chapters) do
        nil -> []
        chapters -> ["-i", chapters_metadata!(chapters, total_duration)]
      end

    other_inputs =
      Enum.flat_map(Map.get(file, :inputs, []), fn {key, clip} ->
        remote_clip(sources[key].video_url, clip)
      end)

    cmd!(
      "ffmpeg",
      ["-hide_banner", "-loglevel", "error", "-y"] ++
        clip_inputs ++
        subtitle_inputs ++
        music_inputs ++
        chapters_inputs ++
        other_inputs ++
        Map.get_lazy(file, :ffmpeg, fn -> default_encoding(file) end) ++
        subtitle_arguments(file, output) ++
        chapters_arguments(file) ++
        font_arguments(file, sources) ++ ["-t", to_string(total_duration), tmp_output]
    )

    if level6 = Map.get(file, :dolby_vision), do: add_dolby_vision!(tmp_output, level6)
    File.rename!(tmp_output, output)

    for {language, flags} <- Map.get(file, :sidecars, []) do
      write_sidecar!(source, language, flags, first_start, total_duration, output)
    end
  end

  defp remote_clip(url, {start, duration} = clip) do
    ["-seek_timestamp", "1", "-ss", to_string(start), "-t", to_string(duration)] ++
      ["-i", cached_clip!(url, clip)]
  end

  # The clip with 5 s around it and its original timestamps, downloaded once for every file
  # cut from it
  defp cached_clip!(url, {start, duration}) do
    path = Path.join([@cache, "clips", "#{:erlang.phash2({url, start, duration})}.mkv"])
    tmp_path = Path.rootname(path) <> ".downloading.mkv"

    unless File.exists?(path) do
      File.mkdir_p!(Path.dirname(path))

      # Seeking to the start of an Ogg file loses its first half second of sound
      seek = if start > 5, do: ["-ss", to_string(start - 5)], else: []

      cmd!(
        "ffmpeg",
        ["-hide_banner", "-loglevel", "error", "-y"] ++
          seek ++
          ["-t", to_string(min(start, 5) + duration + 5), "-user_agent", @user_agent] ++
          @reconnect ++
          ["-i", url, "-map", "0:v?", "-map", "0:a?", "-c", "copy", "-copyts", tmp_path]
      )

      # ffmpeg ends a download cut short by the server without an error. The duration of an
      # MKV with the original timestamps is the end of the clip
      %{"format" => %{"duration" => end_time}} =
        "ffprobe"
        |> cmd!(~w(-v error -show_entries format=duration -of json) ++ [tmp_path])
        |> JSON.decode!()

      if String.to_float(end_time) < start + duration - 1 do
        Mix.raise("The download of #{url} stopped at #{end_time} s: try again later")
      end

      File.rename!(tmp_path, path)
    end

    path
  end

  # The whole music, which is looped when it is shorter than the file
  defp music!(source) do
    cached_download!(source.audio_url, "music", Path.extname(URI.parse(source.audio_url).path))
  end

  defp subtitle_input!(file, sources, language, flags, start, duration) do
    srt = sources |> Map.fetch!(file.source) |> subtitle_clip!(language, start, duration)

    case flag_option(flags, :format, :srt) do
      :srt -> ["-i", srt]
      :ass -> ["-i", ass_subtitle!(srt, sources[file.font].font_family)]
      format -> picture_subtitle!(srt, format)
    end
  end

  defp default_encoding(file) do
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

    video_codec =
      case Map.get(file, :codec, :hevc) do
        :hevc ->
          ["-c:v", "libx265", "-crf", "30", "-tag:v", "hvc1", "-x265-params", "log-level=error"]

        :h264 ->
          ["-c:v", "libx264", "-preset", "slow", "-crf", "28"]
      end

    ["-filter_complex", filter] ++
      media_maps ++ video_codec ++ ["-c:a", "aac", "-b:a", "128k", "-ac", "2"]
  end

  # The subtitle inputs, with their language, flags and a codec that the container takes
  defp subtitle_arguments(file, output) do
    clip_count = length(file.clips)

    file
    |> Map.get(:subtitles, [])
    |> Enum.with_index()
    |> Enum.flat_map(fn {{language, flags}, index} ->
      format = flag_option(flags, :format, :srt)

      codec =
        cond do
          format in [:pgs, :vobsub] -> "copy"
          Path.extname(output) in ~w(.mp4 .m4v .mov) -> "mov_text"
          Path.extname(output) == ".webm" -> "webvtt"
          true -> to_string(format)
        end

      ["-map", "#{clip_count + index}:s:0", "-metadata:s:s:#{index}", "language=#{language}"] ++
        ["-disposition:s:#{index}", disposition(flags), "-c:s:#{index}", codec]
    end)
  end

  # Flags are dispositions, such as :forced, and options, such as `format: :pgs`
  defp disposition(flags) do
    case Enum.filter(flags, &is_atom/1) do
      [] -> "0"
      dispositions -> Enum.map_join(dispositions, "+", &to_string/1)
    end
  end

  defp flag_option(flags, key, default) do
    flags |> List.keyfind(key, 0, {key, default}) |> elem(1)
  end

  defp chapters_arguments(%{chapters: _chapters} = file) do
    input = length(file.clips) + length(Map.get(file, :subtitles, [])) + music_count(file)
    ["-map_metadata", to_string(input), "-map_chapters", to_string(input)]
  end

  defp chapters_arguments(_file), do: []

  defp music_count(file), do: if(Map.has_key?(file, :music), do: 1, else: 0)

  defp font_arguments(%{font: key}, sources) do
    url = sources[key].font_url
    file_name = URI.decode(Path.basename(URI.parse(url).path))

    ["-attach", cached_download!(url, "fonts", Path.extname(file_name))] ++
      ["-metadata:s:t:0", "mimetype=font/ttf", "-metadata:s:t:0", "filename=#{file_name}"]
  end

  defp font_arguments(_file, _sources), do: []

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

  # The SRT in ASS, in the given font
  defp ass_subtitle!(srt, font_family) do
    path = Path.rootname(srt) <> "-#{:erlang.phash2(font_family)}.ass"
    cmd!("ffmpeg", ["-hide_banner", "-loglevel", "error", "-y", "-i", srt, "-c:s", "ass", path])

    content =
      path
      |> File.read!()
      |> String.replace("Style: Default,Arial,", "Style: Default,#{font_family},")

    File.write!(path, content)
    path
  end

  # The input of the SRT as pictures, in a Blu-ray .sup or a VobSub .idx and .sub
  defp picture_subtitle!(srt, format) do
    {seconv_format, resolution, extension} =
      case format do
        :pgs -> {"bluraysup", "1920x1080", ".sup"}
        :vobsub -> {"vobsub", "720x480", ".idx"}
      end

    cmd!("seconv", [
      srt,
      seconv_format,
      "--resolution:#{resolution}",
      "--output-folder:#{Path.dirname(srt)}",
      "--overwrite"
    ])

    path = Path.rootname(srt) <> extension

    # ffmpeg moves the start of an input to 0, which shifts a .sup: it has a start, unlike an SRT
    %{"format" => probed} =
      "ffprobe"
      |> cmd!(~w(-v error -show_entries format=start_time -of json) ++ [path])
      |> JSON.decode!()

    case probed do
      %{"start_time" => start_time} -> ["-itsoffset", start_time, "-i", path]
      _no_start -> ["-i", path]
    end
  end

  # mkvmerge writes the Dolby Vision configuration that ffmpeg doesn't find in raw HEVC
  defp add_dolby_vision!(path, level6) do
    base = Path.rootname(path)

    [hevc, rpu, config, with_rpu, muxed] =
      Enum.map(~w(.hevc .rpu .json .dv.hevc .dv.mkv), &(base <> &1))

    cmd!("ffmpeg", [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-i",
      path,
      "-map",
      "0:v:0",
      "-c",
      "copy",
      hevc
    ])

    %{"streams" => [%{"nb_read_packets" => frames, "r_frame_rate" => frame_rate}]} =
      "ffprobe"
      |> cmd!(
        ~w(-v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets,r_frame_rate -of json) ++
          [path]
      )
      |> JSON.decode!()

    File.write!(
      config,
      JSON.encode!(%{profile: "8.1", length: String.to_integer(frames), level6: level6})
    )

    cmd!("dovi_tool", ["generate", "-j", config, "-o", rpu])
    cmd!("dovi_tool", ["inject-rpu", "-i", hevc, "--rpu-in", rpu, "-o", with_rpu])

    cmd!("mkvmerge", [
      "-q",
      "-o",
      muxed,
      "--default-duration",
      "0:#{frame_rate}fps",
      with_rpu,
      "--no-video",
      path
    ])

    File.rename!(muxed, path)
    Enum.each([hevc, rpu, config, with_rpu], &File.rm!/1)
  end

  defp write_sidecar!(source, language, flags, start, duration, output) do
    format = flag_option(flags, :format, :srt)
    names = [Map.fetch!(@two_letter_codes, language) | Enum.filter(flags, &is_atom/1)]
    path = Path.rootname(output) <> ".#{Enum.map_join(names, ".", &to_string/1)}.#{format}"
    codec = if format == :vtt, do: "webvtt", else: "srt"
    srt = subtitle_clip!(source, language, start, duration)
    cmd!("ffmpeg", ["-hide_banner", "-loglevel", "error", "-y", "-i", srt, "-c:s", codec, path])

    if charset = flag_option(flags, :charset, nil) do
      {content, 0} = System.cmd("iconv", ["-f", "UTF-8", "-t", charset, path])
      File.write!(path, content)
    end
  end

  # The subtitles of the clip. Seeking in the input would shift them by the time between the
  # start and the subtitle before it, so the output drops what comes before the start instead
  defp subtitle_clip!(source, language, start, duration) do
    srt = source.subtitle_urls |> Map.fetch!(language) |> cached_download!("subtitles", ".srt")
    path = Path.rootname(srt) <> "-#{start}-#{duration}.srt"

    cmd!(
      "ffmpeg",
      ["-hide_banner", "-loglevel", "error", "-y", "-i", srt, "-ss", to_string(start)] ++
        ["-t", to_string(duration), "-output_ts_offset", "-#{start}", "-c:s", "srt", path]
    )

    # A subtitle that ends after the clip would make the file longer
    clip_end = Time.add(~T[00:00:00.000], round(duration * 1000), :millisecond)

    content =
      Regex.replace(~r/ --> (\d\d:\d\d:\d\d),(\d\d\d)/, File.read!(path), fn arrow, time, ms ->
        if Time.compare(Time.from_iso8601!("#{time}.#{ms}"), clip_end) == :gt,
          do: " --> " <> String.replace(Time.to_string(clip_end), ".", ","),
          else: arrow
      end)

    File.write!(path, content)
    path
  end

  defp cached_download!(url, directory, extension) do
    path = Path.join([@cache, directory, "#{:erlang.phash2(url)}#{extension}"])

    unless File.exists?(path) do
      File.mkdir_p!(Path.dirname(path))

      %{status: 200, body: body} =
        Req.get!(url, headers: [user_agent: @user_agent], decode_body: false)

      File.write!(path, body)
    end

    path
  end

  # Wikimedia answers 429 Too Many Requests when it gets too many: wait, then try again
  defp cmd!(command, arguments, attempt \\ 1) do
    case System.cmd(command, arguments, stderr_to_stdout: true) do
      {output, 0} ->
        output

      {log, status} ->
        if attempt < 5 and String.contains?(log, "429 Too Many Requests") do
          Mix.shell().info("Too many requests, trying again in a minute")
          Process.sleep(60_000)
          cmd!(command, arguments, attempt + 1)
        else
          Mix.raise("#{command} exited with #{status}:\n#{log}")
        end
    end
  end

  defp write_attribution!(sources, files) do
    # A file's works are its source and the sources of its other inputs
    rows =
      files
      |> Enum.flat_map(fn file ->
        Enum.map(
          Enum.uniq(
            [file.source | Keyword.keys(Map.get(file, :inputs, []))] ++
              for({key, _start, _duration} <- file.clips, do: key)
          ),
          &{sources[&1], file.path}
        )
      end)
      |> Enum.group_by(fn {source, _path} -> source.page_url end)
      |> Enum.map(fn {_page_url, [{source, _path} | _] = works} ->
        {source, works |> Enum.map(&elem(&1, 1)) |> Enum.uniq()}
      end)
      |> Enum.sort_by(fn {source, _paths} -> String.downcase(source.title) end)
      |> Enum.map_join("\n", fn {source, paths} ->
        "| #{work_cells(source)} | " <> Enum.map_join(paths, "<br>", &"`#{&1}`") <> " |"
      end)

    added_rows =
      files
      |> Enum.flat_map(&[Map.get(&1, :music), Map.get(&1, :font)])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.map_join("\n", fn key ->
        "| #{work_cells(sources[key])} |"
      end)

    File.write!(Path.join(@catalog, "ATTRIBUTION.md"), """
    # Attribution

    Generated by `mix dev.catalog.build` from `manifest/`. Each file in `media/` is a clip of
    the work it is listed with, cut, scaled and re-encoded, and some have subtitles, chapters,
    music or fonts added. Each file keeps the license of its work: files cut from a CC BY-SA
    work are under CC BY-SA too. Subtitles taken from Wikimedia Commons are by its
    contributors, under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

    | Work | Author | License | Files |
    | --- | --- | --- | --- |
    #{rows}

    ## Music added to silent films, and fonts attached to subtitles

    | Work | Author | License |
    | --- | --- | --- |
    #{added_rows}
    """)
  end

  # The work, author and license cells of a table row, where a | would start another cell
  defp work_cells(source) do
    "[#{source.title}](#{source.page_url}) | #{String.replace(source.author, "|", "\\|")} | " <>
      "[#{source.license}](#{source.license_url})"
  end
end

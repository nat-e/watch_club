defmodule WatchClub.Ffmpeg.Trickplay do
  @moduledoc """
  Storage, geometry, and manifest logic for a Video's scrubbing thumbnails.

  Sprite sheets are JPEG grids of `@columns` x `@rows` tiles, one per
  `@interval_seconds` slot, each tile scaled to `@tile_width` wide with an even
  height derived from the source aspect ratio. Files land in
  `<trickplay root>/<video_id>/` as `0.jpg`, `1.jpg`, … next to a `meta.json`
  freezing the generation-time geometry, sheet count, and source duration.

  Sprites and metadata are written together at generation time (see
  `WatchClub.MediaCatalog.Workers.GenerateTrickplay`); the WebVTT manifest is
  built at serve time from the metadata alone, so cues always match the sprites
  on disk even across re-imports — the caller only supplies the session-scoped
  URL base the cue sprite refs hang off.
  """

  alias WatchClub.MediaCatalog.VideoTrack

  require Logger

  @interval_seconds 5
  @tile_width 320
  @columns 10
  @rows 10
  @metadata_file "meta.json"

  @doc "Directory holding one Video's trickplay sprite sheets."
  def dir(video_id), do: Path.join(trickplay_root(), video_id)

  @doc """
  Whether the Video's sprite sheets are built: `meta.json` is missing until a generation
  succeeds.
  """
  def generated?(video_id), do: File.exists?(Path.join(dir(video_id), @metadata_file))

  @doc """
  Resolves a sprite-sheet file path for serving. `file_name` comes from the URL,
  so it's restricted to a numeric sheet name (`0.jpg`, `1.jpg`, …) — the guard
  that stops a request escaping the trickplay tree or reaching `meta.json`.
  `video_id` is the trusted, session-resolved Media id.
  """
  def sprite_path(video_id, file_name) do
    path = Path.join(dir(video_id), file_name)

    cond do
      not Regex.match?(~r/^\d+\.jpg$/, file_name) -> {:error, :invalid_segment}
      not File.exists?(path) -> {:error, :not_found}
      true -> {:ok, path}
    end
  end

  @doc """
  Tile pixel dimensions for a source track: `@tile_width` wide, with an even
  height derived from the source aspect ratio. Forcing an even height keeps
  JPEG 4:2:0 happy and the value deterministic.
  """
  def tile_dimensions(%VideoTrack{width: width, height: height}) do
    {@tile_width, round(@tile_width * height / width / 2) * 2}
  end

  @doc """
  Wipes the Video's trickplay directory and rebuilds its sprite sheets: JPEG
  grids of `@columns` x `@rows` tiles, one per `@interval_seconds` slot until
  `duration` (seconds, nullable), each scaled to the (forced) tile dimensions
  derived from `track`. Files are named `0.jpg`, `1.jpg`, … Once ffmpeg
  succeeds, writes `meta.json` with the geometry, sheet count, and `duration`
  the manifest is built from — until then the Video simply has no manifest.
  Returns `:ok`; crashes (and the job retries) if ffmpeg fails.

  Each tile shows the saved frame nearest the middle of its slot. ffmpeg saves
  only keyframes, unless the `:trickplay_keyframes_only` config is off or the
  keyframes can't be read; it then saves one frame per slot from a full decode.
  """
  def generate_sprites!(video_id, source_path, %VideoTrack{} = track, duration) do
    dir = dir(video_id)
    File.rm_rf!(dir)
    frames_dir = Path.join(dir, "frames")
    slots_dir = Path.join(dir, "slots")
    File.mkdir_p!(slots_dir)

    {tile_width, tile_height} = tile_dimensions(track)

    duration =
      try do
        frames = extract_frames!(source_path, frames_dir, "scale=#{tile_width}:#{tile_height}")
        # Without a known duration, the tiles last an interval past the last frame.
        {last_frame_time, _path} = List.last(frames)
        duration = duration || last_frame_time + @interval_seconds

        for slot <- 0..(max(round(duration / @interval_seconds), 1) - 1) do
          middle = (slot + 0.5) * @interval_seconds
          {_time, path} = Enum.min_by(frames, fn {time, _path} -> abs(time - middle) end)
          File.cp!(path, Path.join(slots_dir, "#{slot}.jpg"))
        end

        {_output, 0} =
          run_ffmpeg([
            "-i",
            Path.join(slots_dir, "%d.jpg"),
            "-vf",
            "tile=#{@columns}x#{@rows}",
            "-q:v",
            "4",
            # image2 numbers `%d` from 1 by default; force 0 so the manifest's
            # zero-based sheet index lines up with the files.
            "-start_number",
            "0",
            Path.join(dir, "%d.jpg")
          ])

        duration
      after
        File.rm_rf!(frames_dir)
        File.rm_rf!(slots_dir)
      end

    metadata = %{
      interval_seconds: @interval_seconds,
      tile_width: tile_width,
      tile_height: tile_height,
      columns: @columns,
      rows: @rows,
      sheet_count: length(Path.wildcard(Path.join(dir, "*.jpg"))),
      duration_seconds: duration
    }

    # Written to a tmp name then renamed, so the manifest sees either the full
    # generation-time state or none at all (404), never a torn read. The tmp
    # name matches neither the sprite-serving regex nor the `*.jpg` count above.
    tmp_path = Path.join(dir, "#{@metadata_file}.tmp")
    File.write!(tmp_path, Jason.encode!(metadata))
    File.rename!(tmp_path, Path.join(dir, @metadata_file))
    :ok
  end

  @doc """
  Builds the WebVTT thumbnails manifest for a Video from its generation-time
  `meta.json`, so cue geometry and sheet count always match the sprites on
  disk. `base` is the origin-absolute URL prefix the player resolves sprite
  refs against, and `query`, such as `?token=…`, follows each of them. Returns `{:error, :not_found}` while no metadata exists
  (never generated, or a regeneration in flight has wiped the directory).
  """
  def manifest(video_id, base, query) do
    with {:ok, json} <- File.read(Path.join(dir(video_id), @metadata_file)),
         {:ok, meta} <- Jason.decode(json) do
      %{
        "interval_seconds" => interval,
        "tile_width" => tile_width,
        "tile_height" => tile_height,
        "columns" => columns,
        "rows" => rows,
        "sheet_count" => sheet_count,
        "duration_seconds" => duration_seconds
      } = meta

      tiles_per_sheet = columns * rows
      tile_max = sheet_count * tiles_per_sheet
      duration = duration_seconds || tile_max * interval

      # ffmpeg's `fps` filter rounds the frame count at the end of the source,
      # and even a sub-interval video still yields its first frame.
      count = min(max(round(duration / interval), 1), tile_max)

      cues =
        Enum.map(0..(count - 1)//1, fn i ->
          sheet = div(i, tiles_per_sheet)
          position = rem(i, tiles_per_sheet)
          x = rem(position, columns) * tile_width
          y = div(position, columns) * tile_height

          start_time = i * interval
          end_time = min((i + 1) * interval, duration)

          "#{timestamp(start_time)} --> #{timestamp(end_time)}\n" <>
            "#{base}/#{sheet}.jpg#{query}#xywh=#{x},#{y},#{tile_width},#{tile_height}"
        end)

      {:ok, "WEBVTT\n\n" <> Enum.join(cues, "\n\n") <> "\n"}
    else
      {:error, _missing_or_invalid} -> {:error, :not_found}
    end
  end

  # Returns the `{time, path}` of each frame saved in `frames_dir`, sorted by
  # time. Keyframes skip decoding the other frames; the full decode is the
  # fallback, because some files can't be read that way.
  defp extract_frames!(source_path, frames_dir, scale) do
    # `select` keeps at most a frame a second when every frame is decoded anyway:
    # decoders that ignore `-skip_frame`, such as VP9's, or files of keyframes only.
    keyframes =
      Application.fetch_env!(:watch_club, :trickplay_keyframes_only) &&
        extract_frames(
          source_path,
          frames_dir,
          ["-skip_frame", "nokey"],
          "select='isnan(prev_selected_t)+gte(abs(t-prev_selected_t),1)',#{scale}"
        )

    case keyframes do
      {:ok, [_ | _] = frames} ->
        frames

      disabled_or_failed ->
        if disabled_or_failed do
          Logger.warning(
            "Can't build Scrubbing Thumbnails from the keyframes of #{source_path}, " <>
              "decoding every frame instead: #{inspect(disabled_or_failed)}"
          )
        end

        {:ok, frames} =
          extract_frames(source_path, frames_dir, [], "fps=1/#{@interval_seconds},#{scale}")

        frames
    end
  end

  defp extract_frames(source_path, frames_dir, input_args, filters) do
    File.rm_rf!(frames_dir)
    File.mkdir_p!(frames_dir)
    times_path = Path.join(frames_dir, "times.txt")

    # Decoders can return keyframes out of order, which the JPEG encoder
    # rejects: `setpts` numbers them in the encoder's time base, and `{ti}`
    # still records their time.
    args =
      input_args ++
        [
          "-i",
          source_path,
          "-an",
          "-sn",
          "-vf",
          "#{filters},setpts=N",
          "-fps_mode",
          "passthrough",
          "-enc_time_base",
          "filter",
          "-q:v",
          "2",
          "-stats_enc_pre",
          times_path,
          "-stats_enc_pre_fmt",
          "{ti}",
          "-start_number",
          "0",
          Path.join(frames_dir, "%d.jpg")
        ]

    case run_ffmpeg(args) do
      {_output, 0} ->
        frames =
          times_path
          |> File.read!()
          |> String.split("\n", trim: true)
          |> Enum.with_index(fn time, index ->
            {time, ""} = Float.parse(time)
            {time, Path.join(frames_dir, "#{index}.jpg")}
          end)
          |> Enum.sort()

        {:ok, frames}

      {output, status} ->
        {:error, "ffmpeg exited with #{status}: #{String.trim(output)}"}
    end
  end

  # At the lowest CPU priority, so Playback transcodes get the CPU first.
  defp run_ffmpeg(args) do
    args = ["-n", "19", "ffmpeg", "-hide_banner", "-loglevel", "error", "-y" | args]
    Logger.debug("Running trickplay ffmpeg job: nice #{Enum.join(args, " ")}")
    System.cmd("nice", args, stderr_to_stdout: true)
  end

  defp trickplay_root,
    do: Path.join(Application.fetch_env!(:watch_club, :app_data), "trickplay")

  defp timestamp(seconds) do
    total_ms = round(seconds * 1000)
    hours = div(total_ms, 3_600_000)
    minutes = div(rem(total_ms, 3_600_000), 60_000)
    secs = div(rem(total_ms, 60_000), 1000)
    millis = rem(total_ms, 1000)

    "#{pad(hours)}:#{pad(minutes)}:#{pad(secs)}.#{String.pad_leading("#{millis}", 3, "0")}"
  end

  defp pad(value), do: String.pad_leading("#{value}", 2, "0")
end

defmodule WatchClub.Ffmpeg.AudioFingerprint do
  @moduledoc """
  Chromaprint fingerprints of the beginning and the end of a Video's audio, and
  the search for the audio two of them share, such as an Intro.

  A fingerprint covers the first or the last 10 minutes of the Video, at most a
  quarter of it. Fingerprints are cached in `<app data>/fingerprints/<video_id>/`:
  deleting them only costs computing them again.
  """

  import Bitwise

  @ffprobe Application.compile_env(:watch_club, :ffprobe, WatchClub.Ffmpeg)

  # Chromaprint's default algorithm gives a point every 4096 / 3 samples at 11025 Hz
  @seconds_per_point 4096 / 3 / 11_025
  @max_window_seconds 600
  # Jellyfin's Intro Skipper thresholds: aligned points match when at most 6 of their
  # 32 bits differ, and shared audio goes on across up to 3.5 seconds of mismatches.
  @max_differing_bits 6
  @max_gap_points round(3.5 / @seconds_per_point)

  @enforce_keys [:offset_seconds, :points]
  defstruct [:offset_seconds, :points]

  @type t :: %__MODULE__{offset_seconds: float(), points: tuple()}

  @doc """
  Fingerprint of the `:beginning` or the `:end` of the Video's audio, from the
  cache or computed with ffmpeg and fpcalc.
  """
  def fetch!(video_id, path, duration_seconds, part) when part in [:beginning, :end] do
    seconds = min(@max_window_seconds, duration_seconds / 4)
    offset_seconds = if part == :beginning, do: 0.0, else: duration_seconds - seconds
    file = Path.join(dir(video_id), "#{part}.raw")

    binary =
      case File.read(file) do
        {:ok, binary} -> binary
        {:error, :enoent} -> compute!(path, offset_seconds, seconds, file)
      end

    points = for <<point::little-32 <- binary>>, do: point
    %__MODULE__{offset_seconds: offset_seconds, points: List.to_tuple(points)}
  end

  @doc "Deletes the Video's cached fingerprints."
  def delete!(video_id), do: File.rm_rf!(dir(video_id))

  @doc """
  The longest audio that `a` and `b` share, from `min_seconds` to `max_seconds`
  (a number or `:infinity`) long, as `{{start, end}, {start, end}}`: its times in
  `a`'s Video, then in `b`'s. Nil when they share none.
  """
  def shared_range(%__MODULE__{} = a, %__MODULE__{} = b, min_seconds, max_seconds) do
    # One position per point value: repeated values, such as silence, would only add
    # alignments to try
    b_positions = b.points |> Tuple.to_list() |> Enum.with_index() |> Map.new()

    a.points
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.flat_map(fn {point, a_position} ->
      case b_positions do
        %{^point => b_position} -> [b_position - a_position]
        _ -> []
      end
    end)
    |> Enum.uniq()
    |> Enum.flat_map(fn shift -> shared_runs(a.points, b.points, shift) end)
    |> Enum.filter(fn {first, last, _shift} ->
      # Any number is smaller than the atom :infinity
      seconds = (last - first + 1) * @seconds_per_point
      seconds >= min_seconds and seconds <= max_seconds
    end)
    |> Enum.max_by(fn {first, last, _shift} -> last - first end, fn -> nil end)
    |> case do
      nil ->
        nil

      {first, last, shift} ->
        {range(a, first, last), range(b, first + shift, last + shift)}
    end
  end

  # Runs of points of `a` that match the points of `b` `shift` positions further
  defp shared_runs(a, b, shift) do
    first = max(0, -shift)
    last = min(tuple_size(a), tuple_size(b) - shift) - 1

    for position <- first..last//1,
        popcount(bxor(elem(a, position), elem(b, position + shift))) <= @max_differing_bits do
      position
    end
    |> Enum.chunk_while(
      [],
      fn
        position, [previous | _] = run when position - previous <= @max_gap_points ->
          {:cont, [position | run]}

        position, [] ->
          {:cont, [position]}

        position, run ->
          {:cont, run, [position]}
      end,
      fn
        [] -> {:cont, []}
        run -> {:cont, run, []}
      end
    )
    |> Enum.map(fn run -> {List.last(run), hd(run), shift} end)
  end

  defp range(fingerprint, first, last) do
    {fingerprint.offset_seconds + first * @seconds_per_point,
     fingerprint.offset_seconds + (last + 1) * @seconds_per_point}
  end

  # Number of bits set in a 32-bit integer
  defp popcount(value) do
    value = value - (value >>> 1 &&& 0x55555555)
    value = (value &&& 0x33333333) + (value >>> 2 &&& 0x33333333)
    value = value + (value >>> 4) &&& 0x0F0F0F0F
    (value * 0x01010101 &&& 0xFFFFFFFF) >>> 24
  end

  defp compute!(path, offset_seconds, seconds, file) do
    {:ok, points} = @ffprobe.audio_fingerprint(path, offset_seconds, seconds)
    binary = for point <- points, into: <<>>, do: <<point::little-32>>

    # Written to a tmp name then renamed, so a reader never sees a partial file
    File.mkdir_p!(Path.dirname(file))
    File.write!("#{file}.tmp", binary)
    File.rename!("#{file}.tmp", file)
    binary
  end

  defp dir(video_id),
    do: Path.join([Application.fetch_env!(:watch_club, :app_data), "fingerprints", video_id])
end

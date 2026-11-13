defmodule WatchClub.Ffmpeg.MatroskaCues do
  @moduledoc """
  Reads the keyframes of a Matroska file's first video track from its Cues: the index of
  keyframes that muxers write for seeking. It reads a few kilobytes where a scan of the
  file's frames reads all of it.

  The Segment's SeekHead tells where its Info, Tracks and Cues are; elements that come
  before the first Cluster are found without it.
  """

  import Bitwise

  @ebml 0x1A45DFA3
  @segment 0x18538067
  @seek_head 0x114D9B74
  @seek 0x4DBB
  @seek_id 0x53AB
  @seek_position 0x53AC
  @info 0x1549A966
  @timestamp_scale 0x2AD7B1
  @tracks 0x1654AE6B
  @track_entry 0xAE
  @track_number 0xD7
  @track_type 0x83
  @video_track_type 1
  @cluster 0x1F43B675
  @cues 0x1C53BB6B
  @cue_point 0xBB
  @cue_time 0xB3
  @cue_track_positions 0xB7
  @cue_track 0xF7

  # Matroska's default: timestamps count milliseconds
  @default_timestamp_scale 1_000_000

  @doc """
  The times, in seconds of the file's timestamps, of the first video track's keyframes that
  the Cues list, in order. `:error` when the file isn't Matroska, or has no Cues for that
  track.
  """
  @spec keyframe_times(String.t()) :: {:ok, [float()]} | :error
  def keyframe_times(path) do
    File.open!(path, [:read, :raw, :binary], fn file ->
      with {:ok, offsets} <- element_offsets(file),
           {:ok, track_number} <- first_video_track(file, offsets[@tracks]),
           {:ok, cue_points} <- body_at(file, offsets[@cues], @cues) do
        scale = timestamp_scale(file, offsets[@info])

        cue_points
        |> children()
        |> Enum.filter(fn {id, _body} -> id == @cue_point end)
        |> Enum.flat_map(fn {_id, body} -> cue_time(body, track_number) end)
        |> Enum.map(&(&1 * scale / 1_000_000_000))
        |> Enum.sort()
        |> Enum.dedup()
        |> case do
          [] -> :error
          times -> {:ok, times}
        end
      end
    end)
  end

  # The offsets of the Segment's top-level elements, by ID: those before its first Cluster, and
  # those its SeekHeads point to
  defp element_offsets(file) do
    with {:ok, @ebml, body, size} <- header_at(file, 0),
         {:ok, @segment, segment_start, _size} <- header_at(file, body + size) do
      offsets = offsets_before_cluster(file, segment_start, %{})

      offsets =
        offsets
        |> Map.take([@seek_head])
        |> Map.values()
        |> Enum.reduce(offsets, fn seek_head, offsets ->
          Map.merge(seek_entries(file, segment_start, seek_head), offsets)
        end)

      {:ok, offsets}
    end
  end

  defp offsets_before_cluster(file, offset, offsets) do
    case header_at(file, offset) do
      {:ok, @cluster, _body, _size} ->
        offsets

      {:ok, id, body, size} ->
        offsets_before_cluster(file, body + size, Map.put_new(offsets, id, offset))

      :error ->
        offsets
    end
  end

  # Positions in a SeekHead count from the start of the Segment's body
  defp seek_entries(file, segment_start, seek_head) do
    case body_at(file, seek_head, @seek_head) do
      {:ok, body} ->
        for {@seek, seek} <- children(body),
            entry = Map.new(children(seek)),
            Map.has_key?(entry, @seek_id) and Map.has_key?(entry, @seek_position),
            into: %{} do
          {:binary.decode_unsigned(entry[@seek_id]),
           segment_start + :binary.decode_unsigned(entry[@seek_position])}
        end

      :error ->
        %{}
    end
  end

  defp first_video_track(file, tracks) do
    with {:ok, body} <- body_at(file, tracks, @tracks) do
      Enum.find_value(children(body), :error, fn
        {@track_entry, entry} ->
          entry = Map.new(children(entry))

          if unsigned(entry[@track_type]) == @video_track_type and entry[@track_number] do
            {:ok, unsigned(entry[@track_number])}
          end

        _other ->
          nil
      end)
    end
  end

  defp timestamp_scale(file, info) do
    case body_at(file, info, @info) do
      {:ok, body} ->
        body |> children() |> Map.new() |> Map.get(@timestamp_scale) |> unsigned() ||
          @default_timestamp_scale

      :error ->
        @default_timestamp_scale
    end
  end

  # The CuePoint's time when one of its positions is in the track
  defp cue_time(cue_point, track_number) do
    elements = children(cue_point)

    in_track? =
      Enum.any?(elements, fn
        {@cue_track_positions, positions} ->
          positions |> children() |> Map.new() |> Map.get(@cue_track) |> unsigned() ==
            track_number

        _other ->
          false
      end)

    case List.keyfind(elements, @cue_time, 0) do
      {@cue_time, time} when in_track? -> [unsigned(time)]
      _missing_or_other_track -> []
    end
  end

  defp body_at(_file, nil, _id), do: :error

  defp body_at(file, offset, id) do
    with {:ok, ^id, body, size} <- header_at(file, offset),
         {:ok, data} when byte_size(data) == size <- :file.pread(file, body, size) do
      {:ok, data}
    else
      _other -> :error
    end
  end

  # The element at `offset`: its ID, where its body starts, and its size. `:error` past the end
  # of the file, or for an element whose size is unknown.
  defp header_at(file, offset) do
    with {:ok, data} <- :file.pread(file, offset, 12),
         {:ok, id, id_length, rest} <- vint(data),
         {:ok, size, size_length, _rest} <- vint(rest),
         {:ok, size} <- known_size(size, size_length) do
      {:ok, id, offset + id_length + size_length, size}
    else
      _eof_or_invalid -> :error
    end
  end

  # The elements in `data`, as `{id, body}`, up to the first one that doesn't fit
  defp children(data) do
    with {:ok, id, _id_length, rest} <- vint(data),
         {:ok, size, size_length, rest} <- vint(rest),
         {:ok, size} <- known_size(size, size_length),
         <<body::binary-size(^size), rest::binary>> <- rest do
      [{id, body} | children(rest)]
    else
      _end_or_invalid -> []
    end
  end

  # An EBML variable-length integer, with its length marker: an element ID keeps it, a size
  # drops it
  defp vint(<<first, _rest::binary>> = data) when first > 0 do
    length = Enum.find(1..8, &(first >= 0x100 >>> &1))

    case data do
      <<value::unit(8)-size(^length), rest::binary>> -> {:ok, value, length, rest}
      _too_short -> :error
    end
  end

  defp vint(_data), do: :error

  # A size of all ones means unknown
  defp known_size(raw, length) do
    size = raw &&& (1 <<< (7 * length)) - 1
    if size == (1 <<< (7 * length)) - 1, do: :error, else: {:ok, size}
  end

  defp unsigned(nil), do: nil
  defp unsigned(data), do: :binary.decode_unsigned(data)
end

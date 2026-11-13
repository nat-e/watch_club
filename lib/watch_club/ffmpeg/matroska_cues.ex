defmodule WatchClub.Ffmpeg.MatroskaCues do
  @moduledoc """
  Reads the keyframes of a Matroska file's video track from its Cues: the index of keyframes
  that muxers write for seeking. It reads a few kilobytes where a scan of the file's frames
  reads all of it.

  The Segment's SeekHead tells where its Info, Tracks and Cues are; elements that come before
  the first Cluster are found without it.
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
  The times, in seconds of the file's timestamps, of the keyframes that the Cues list for the
  video stream at `stream_index`, in order. ffmpeg numbers a Matroska file's streams in the
  order of its tracks. `:error` when the file isn't Matroska, or its Cues are missing, list no
  keyframe of that stream, or can't be read.
  """
  @spec keyframe_times(String.t(), non_neg_integer()) :: {:ok, [float()]} | :error
  def keyframe_times(path, stream_index) do
    File.open!(path, [:read, :raw, :binary], fn file ->
      offsets = element_offsets(file)
      track_number = track_number(body!(file, offsets, @tracks), stream_index)
      scale = timestamp_scale(body!(file, offsets, @info))

      body!(file, offsets, @cues)
      |> children()
      |> Enum.flat_map(fn
        {@cue_point, cue_point} -> cue_time(cue_point, track_number)
        _void_or_checksum -> []
      end)
      |> Enum.map(&(&1 * scale / 1_000_000_000))
      |> Enum.sort()
      |> Enum.dedup()
      |> case do
        [] -> :error
        times -> {:ok, times}
      end
    end)
  catch
    :unusable -> :error
  end

  # The offsets of the Segment's top-level elements, by ID: those before its first Cluster, and
  # those its SeekHead points to
  defp element_offsets(file) do
    with {:ok, @ebml, body, size} when is_integer(size) <- header_at(file, 0),
         {:ok, @segment, segment_start, _size} <- header_at(file, body + size) do
      offsets = offsets_before_cluster(file, segment_start, %{})

      if offsets[@seek_head] do
        Map.merge(seek_entries(body!(file, offsets, @seek_head), segment_start), offsets)
      else
        offsets
      end
    else
      _not_matroska -> throw(:unusable)
    end
  end

  # Stops at the end of the file, and at an element whose size is unknown
  defp offsets_before_cluster(file, offset, offsets) do
    case header_at(file, offset) do
      {:ok, @cluster, _body, _size} ->
        offsets

      {:ok, id, body, size} when is_integer(size) ->
        offsets_before_cluster(file, body + size, Map.put_new(offsets, id, offset))

      _end ->
        offsets
    end
  end

  # Positions in a SeekHead count from the start of the Segment's body
  defp seek_entries(seek_head, segment_start) do
    for {@seek, seek} <- children(seek_head), into: %{} do
      case Map.new(children(seek)) do
        %{@seek_id => id, @seek_position => position} ->
          {unsigned(id), segment_start + unsigned(position)}

        _incomplete ->
          throw(:unusable)
      end
    end
  end

  defp track_number(tracks, stream_index) do
    entries = for {@track_entry, entry} <- children(tracks), do: Map.new(children(entry))

    case Enum.at(entries, stream_index) do
      %{@track_type => type, @track_number => number} ->
        if unsigned(type) == @video_track_type, do: unsigned(number), else: throw(:unusable)

      _missing ->
        throw(:unusable)
    end
  end

  defp timestamp_scale(info) do
    case Map.new(children(info)) do
      %{@timestamp_scale => scale} ->
        if unsigned(scale) > 0, do: unsigned(scale), else: throw(:unusable)

      _default ->
        @default_timestamp_scale
    end
  end

  # The CuePoint's time when one of its positions is in the track
  defp cue_time(cue_point, track_number) do
    elements = children(cue_point)

    tracks =
      for {@cue_track_positions, positions} <- elements do
        case Map.new(children(positions)) do
          %{@cue_track => track} -> unsigned(track)
          _incomplete -> throw(:unusable)
        end
      end

    case List.keyfind(elements, @cue_time, 0) do
      {@cue_time, time} when tracks != [] ->
        if track_number in tracks, do: [unsigned(time)], else: []

      _incomplete ->
        throw(:unusable)
    end
  end

  defp body!(file, offsets, id) do
    with offset when is_integer(offset) <- offsets[id],
         {:ok, ^id, body, size} when is_integer(size) <- header_at(file, offset),
         {:ok, data} when byte_size(data) == size <- :file.pread(file, body, size) do
      data
    else
      _missing_or_unreadable -> throw(:unusable)
    end
  end

  # The element at `offset`: its ID, where its body starts, and its size, nil when unknown.
  # `:error` past the end of the file.
  defp header_at(file, offset) do
    with {:ok, data} <- :file.pread(file, offset, 12),
         {:ok, id, id_length, rest} <- vint(data),
         {:ok, size, size_length, _rest} <- vint(rest) do
      {:ok, id, offset + id_length + size_length, size(size, size_length)}
    else
      _end_or_invalid -> :error
    end
  end

  # The elements that fill `data`, as `{id, body}`
  defp children(<<>>), do: []

  defp children(data) do
    with {:ok, id, _id_length, rest} <- vint(data),
         {:ok, size, size_length, rest} <- vint(rest),
         size when is_integer(size) <- size(size, size_length),
         <<body::binary-size(^size), rest::binary>> <- rest do
      [{id, body} | children(rest)]
    else
      _invalid -> throw(:unusable)
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
  defp size(raw, length) do
    size = raw &&& (1 <<< (7 * length)) - 1
    if size == (1 <<< (7 * length)) - 1, do: nil, else: size
  end

  defp unsigned(nil), do: nil
  defp unsigned(data), do: :binary.decode_unsigned(data)
end

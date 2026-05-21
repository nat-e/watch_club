defmodule WatchClub.Media.ImportPipeline.Candidate do
  @moduledoc false

  defmodule FileInfo do
    @moduledoc false

    defstruct [:size, :modified_at]
  end

  defmodule ContentHints do
    @moduledoc false

    defstruct [
      :title,
      :year,
      :tv_show_title,
      :season_number,
      :episode_number,
      :episode_title,
      :book_title,
      external_ids: %{},
      sources: []
    ]
  end

  defmodule Probe do
    @moduledoc false

    defstruct [
      :media_type,
      :container,
      :duration_seconds,
      :bit_rate,
      video_tracks: [],
      audio_tracks: [],
      text_tracks: []
    ]
  end

  defmodule AudioTrackProbe do
    @moduledoc false

    defstruct [:stream_index, :codec, :language, :title, :channels, default?: false]
  end

  defmodule VideoTrackProbe do
    @moduledoc false

    defstruct [:stream_index, :codec, :width, :height, :frame_rate, :bit_rate]
  end

  defmodule TextTrackSpec do
    @moduledoc false

    defstruct [
      :stream_index,
      :sidecar_path,
      :codec,
      :language,
      :title,
      default?: false,
      forced?: false,
      hearing_impaired?: false
    ]
  end

  alias WatchClub.Media.ImportPipeline.Candidate.FileInfo
  alias WatchClub.Media.ImportConfiguration

  defstruct [
    :path,
    :relative_path,
    :extension,
    :media_type,
    :content_type,
    :file,
    :existing_media,
    :content_hints,
    :probe,
    sidecar_text_tracks: []
  ]

  def new(path, root_path, stat, %ImportConfiguration{} = configuration) do
    expanded_path = Path.expand(path)

    %__MODULE__{
      path: expanded_path,
      relative_path: Path.relative_to(expanded_path, root_path),
      extension: path |> Path.extname() |> String.downcase(),
      media_type: configuration.media_type,
      content_type: configuration.content_type,
      file: %FileInfo{
        size: stat.size,
        modified_at: stat.mtime
      },
      sidecar_text_tracks: []
    }
  end
end

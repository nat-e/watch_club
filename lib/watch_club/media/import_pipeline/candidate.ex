defmodule WatchClub.Media.ImportPipeline.Candidate do
  @moduledoc """
  A file that the pipeline is processing. Stages enrich the candidate with one
  field each as it flows through the pipeline; the final stage assigns an
  `:outcome` representing the terminal verdict (`:created`, `:updated`,
  `:no_match`, or `:failed`).

  Field-by-stage progression:

    * after `Scan`:            `path`, `relative_path`, `extension`, `file_info`
    * after `FilterExisting`:  `existing_media`
    * after `ExtractIdentity`: `identity`
    * after `ExtractStructure` and `Sidecars`: `media_structure`
    * after `ComputeOutcome`:  `outcome`

  Stages return `{:ok, candidate}` on success, or `{:error, candidate}` on
  failure with the candidate's `:outcome` set to a failed `Outcome`. The
  pipeline composes stages with `with/1`, short-circuiting on the first error.
  """

  alias WatchClub.Media.ImportPipeline.Candidate.FileInfo

  defstruct [
    :path,
    :relative_path,
    :extension,
    :file_info,
    :existing_media,
    :identity,
    :media_structure,
    :outcome
  ]

  defmodule FileInfo do
    @moduledoc false
    defstruct [:size, :modified_at]
  end

  defmodule Identity do
    @moduledoc """
    What the file looks like it represents — title, year, season/episode,
    embedded provider IDs. Extracted from the filename and sibling NFO files.
    Consumed by `Match` to resolve the file to a `Content` row.
    """
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

  defmodule MediaStructure do
    @moduledoc """
    The technical shape of the file — container, duration, and the list of
    streams. Extracted by probing the file bytes (and discovering sidecar
    text-track files for videos).
    """

    defstruct [
      :container,
      :duration_seconds,
      :bit_rate,
      video_tracks: [],
      audio_tracks: [],
      text_tracks: []
    ]

    defmodule VideoTrack do
      @moduledoc false
      defstruct [:stream_index, :codec, :width, :height, :frame_rate, :bit_rate]
    end

    defmodule AudioTrack do
      @moduledoc false
      defstruct [:stream_index, :codec, :language, :title, :channels, default?: false]
    end

    defmodule TextTrack do
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
  end

  defmodule Outcome do
    @moduledoc """
    The terminal verdict for a candidate. `status` maps to
    `WatchClub.Media.ImportResultStatus`. `metadata` captures stage-specific
    context (which stage produced the outcome, any structured detail).
    """

    defstruct [:status, :message, metadata: %{}]
  end

  def new(path, root_path, stat) do
    expanded_path = Path.expand(path)

    %__MODULE__{
      path: expanded_path,
      relative_path: Path.relative_to(expanded_path, root_path),
      extension: path |> Path.extname() |> String.downcase(),
      file_info: %FileInfo{size: stat.size, modified_at: stat.mtime}
    }
  end
end

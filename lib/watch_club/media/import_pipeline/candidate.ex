defmodule WatchClub.Media.ImportPipeline.Candidate do
  @moduledoc """
  A file that the pipeline is processing. Stages enrich the candidate with one
  field each as it flows through the pipeline; once every stage has run (or
  the pipeline halts), the candidate is finalized with an `Outcome`.

  Field-by-stage progression:

    * after `Scan`:             `path`, `relative_path`, `extension`, `file_info`
    * after `FilterExisting`:   `existing_media`
    * after `ExtractIdentity`:  `identity`
    * after `ExtractStructure`: `media_structure`
    * after finalization:       `outcome` (or `nil` for skipped candidates)

  Stages do not construct outcomes themselves — they return
  `{:ok, candidate}` or `{:halt, candidate, reason, message}`. The pipeline
  calls `set_outcome/1` on success or `set_halted_outcome/3` on halt to set
  the terminal `Outcome`.
  """

  alias WatchClub.Media.ImportPipeline.Candidate.{FileInfo, Outcome}

  @type t :: %__MODULE__{
          path: String.t() | nil,
          relative_path: String.t() | nil,
          extension: String.t() | nil,
          file_info: FileInfo.t() | nil,
          existing_media: %{id: term(), type: atom()} | nil,
          identity: __MODULE__.Identity.t() | nil,
          media_structure: __MODULE__.MediaStructure.t() | nil,
          outcome: Outcome.t() | nil
        }

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
    @type t :: %__MODULE__{size: non_neg_integer() | nil, modified_at: integer() | nil}
    defstruct [:size, :modified_at]
  end

  defmodule Identity do
    @moduledoc """
    What the file looks like it represents — title, year, season/episode,
    embedded provider IDs. Extracted from the filename and sibling NFO files.
    Consumed by `Match` to resolve the file to a `Content` row.
    """

    @type t :: %__MODULE__{}

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

    @type t :: %__MODULE__{}

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
    `WatchClub.Media.ImportResultStatus`.
    """

    @type t :: %__MODULE__{status: atom(), message: String.t() | nil}

    defstruct [:status, :message]
  end

  @doc """
  Builds a fresh `Candidate` for a discovered file during `Scan`. `path` and
  `root_path` are expected to be absolute paths.
  """
  def new(path, root_path, stat) do
    %__MODULE__{
      path: path,
      relative_path: Path.relative_to(path, root_path),
      extension: path |> Path.extname() |> String.downcase(),
      file_info: %FileInfo{size: stat.size, modified_at: stat.mtime}
    }
  end

  @doc """
  Finalizes a candidate that made it through every stage successfully.
  """
  def set_outcome(%__MODULE__{} = candidate) do
    %{
      candidate
      | outcome: %Outcome{
          status: :no_match,
          message: "Could not confidently match file to Content or TV Show Episode"
        }
    }
  end

  @doc """
  Finalizes a candidate that halted mid-pipeline with the given status and
  message.
  """
  def set_halted_outcome(%__MODULE__{} = candidate, status, message)
      when status in [:skipped, :failed],
      do: %{candidate | outcome: %Outcome{status: status, message: message}}
end

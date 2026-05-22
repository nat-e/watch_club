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
    * after `MatchContent`:     `match` (set only when the candidate resolved to a `Content`)
    * after finalization:       `outcome` (or `nil` for skipped candidates)

  Stages do not construct outcomes themselves — they return
  `{:ok, candidate}` or `{:halt, candidate, reason, message}`. The pipeline
  finalizes candidates via the dedicated `set_*_outcome/*` helpers.
  """

  alias WatchClub.Media.ImportPipeline.Candidate.{FileInfo, MatchInfo, Outcome}

  @type t :: %__MODULE__{
          path: String.t() | nil,
          relative_path: String.t() | nil,
          extension: String.t() | nil,
          file_info: FileInfo.t() | nil,
          existing_media: %{id: Ash.UUIDv7.t(), type: WatchClub.Media.MediaType.t()} | nil,
          identity: __MODULE__.Identity.t() | nil,
          media_structure: __MODULE__.MediaStructure.t() | nil,
          match: MatchInfo.t() | nil,
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
    :match,
    :outcome
  ]

  defmodule FileInfo do
    @moduledoc false
    @type t :: %__MODULE__{size: non_neg_integer() | nil, modified_at: integer() | nil}
    defstruct [:size, :modified_at]
  end

  defmodule ExternalIds do
    @moduledoc """
    Metadata-provider identifiers found for a candidate. All three slots are
    strings (IMDB IDs aren't numeric, and stringifying TMDB/TVDB IDs keeps the
    shape homogeneous with how downstream URL builders use them).
    """

    @type t :: %__MODULE__{
            tmdb: String.t() | nil,
            imdb: String.t() | nil,
            tvdb: String.t() | nil
          }

    defstruct [:tmdb, :imdb, :tvdb]
  end

  defmodule Identity do
    @moduledoc """
    What the file looks like it represents. Filled in by `ExtractIdentity` from
    the filename, the directory structure, and any sibling NFO files. Consumed
    by downstream matching to resolve the candidate to a `Content` row.

    The same struct is used for every content type — a movie populates the
    top group of fields, an episode populates the TV group, a book populates
    title/author/isbn. Unused fields stay `nil`.

    `sources` records, per field, where each value came from
    (`:filename | :nfo_sidecar | :nfo_show | :nfo_season`). Useful for
    debugging and for downstream confidence scoring.
    """

    alias WatchClub.Media.ImportPipeline.Candidate.ExternalIds

    @type source :: :filename | :nfo_sidecar | :nfo_show | :nfo_season

    @type t :: %__MODULE__{
            title: String.t() | nil,
            original_title: String.t() | nil,
            year: integer() | nil,
            premiered: Date.t() | nil,
            plot: String.t() | nil,
            runtime_minutes: integer() | nil,
            tagline: String.t() | nil,
            set_name: String.t() | nil,
            genres: [String.t()],
            studios: [String.t()],
            countries: [String.t()],
            author: String.t() | nil,
            isbn: String.t() | nil,
            episode_title: String.t() | nil,
            season_number: integer() | nil,
            episode_number: integer() | nil,
            aired: Date.t() | nil,
            show_title: String.t() | nil,
            show_year: integer() | nil,
            show_genres: [String.t()],
            show_external_ids: ExternalIds.t(),
            external_ids: ExternalIds.t(),
            sources: %{atom() => source()}
          }

    defstruct title: nil,
              original_title: nil,
              year: nil,
              premiered: nil,
              plot: nil,
              runtime_minutes: nil,
              tagline: nil,
              set_name: nil,
              genres: [],
              studios: [],
              countries: [],
              author: nil,
              isbn: nil,
              episode_title: nil,
              season_number: nil,
              episode_number: nil,
              aired: nil,
              show_title: nil,
              show_year: nil,
              show_genres: [],
              show_external_ids: %ExternalIds{},
              external_ids: %ExternalIds{},
              sources: %{}
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
    `WatchClub.Media.ImportResultStatus`, plus `:skipped` for candidates the
    pipeline finalizes without writing a result row.
    """

    @type status :: WatchClub.Media.ImportResultStatus.t() | :skipped
    @type t :: %__MODULE__{status: status(), message: String.t() | nil}

    defstruct [:status, :message]
  end

  defmodule MatchInfo do
    @moduledoc """
    Set by `MatchContent` after a candidate has been resolved to a `Content`
    and a `Media` row has been created or updated. Used by `ExecuteRun` to
    populate the import result's metadata.
    """

    @type t :: %__MODULE__{
            media_id: Ash.UUIDv7.t(),
            content_id: Ash.UUIDv7.t(),
            attachment:
              {:movie, Ash.UUIDv7.t()} | {:episode, Ash.UUIDv7.t()},
            content_action: :created | :found | :refreshed
          }

    defstruct [:media_id, :content_id, :attachment, :content_action]
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
  Finalizes a candidate whose file became a new `Media`.
  """
  def set_created_outcome(%__MODULE__{} = candidate),
    do: %{candidate | outcome: %Outcome{status: :created}}

  @doc """
  Finalizes a candidate whose existing `Media` was rematched and re-probed
  (Refresh Metadata on).
  """
  def set_updated_outcome(%__MODULE__{} = candidate),
    do: %{candidate | outcome: %Outcome{status: :updated}}

  @doc """
  Finalizes a candidate that could not be confidently matched to `Content` or
  a `TV Show Episode`.
  """
  def set_no_match_outcome(%__MODULE__{} = candidate, message),
    do: %{candidate | outcome: %Outcome{status: :no_match, message: message}}

  @doc """
  Finalizes a candidate that halted mid-pipeline with the given status and
  message.
  """
  def set_halted_outcome(%__MODULE__{} = candidate, status, message)
      when status in [:skipped, :failed, :no_match],
      do: %{candidate | outcome: %Outcome{status: status, message: message}}
end

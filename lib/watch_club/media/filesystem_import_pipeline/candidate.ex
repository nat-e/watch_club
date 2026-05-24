defmodule WatchClub.Media.ImportPipeline.Candidate do
  @moduledoc """
  A file that the pipeline is processing. Stages enrich the candidate with one
  field each as it flows through the pipeline; once every stage has run (or
  the pipeline halts).
  """

  @type t :: %__MODULE__{
          path: String.t() | nil,
          identity:
            __MODULE__.MovieIdentity.t()
            | __MODULE__.EpisodeIdentity.t()
            | __MODULE__.BookIdentity.t()
            | nil,
          media_structure: __MODULE__.MediaStructure.t() | nil,
          match_result: __MODULE__.MatchResult.t() | nil
        }

  defstruct [
    :path,
    :relative_path,
    :identity,
    :media_structure,
    :match_result
  ]

  defmodule MatchResult do
    @moduledoc """
    Outcome of the `MatchContent` stage. `:success` means the candidate's
    identity was resolved to a Content row (its id is in `matched_id`);
    `:not_matched` means the stage ran but no Content could be resolved.
    A `nil` `match_result` on the parent `Candidate` means the stage has
    not yet run.
    """

    @type t :: %__MODULE__{
            result: :success | :not_matched,
            matched_id: Ash.UUIDv7.t() | nil
          }

    defstruct [:result, :matched_id]
  end

  defmodule MovieIdentity do
    @type t :: %__MODULE__{
            tmdb_id: integer() | nil,
            imdb_id: String.t() | nil,
            title: String.t() | nil,
            year: integer() | nil
          }

    defstruct tmdb_id: nil,
              imdb_id: nil,
              title: nil,
              year: nil
  end

  defmodule EpisodeIdentity do
    @type t :: %__MODULE__{
            tmdb_id: integer() | nil,
            tvdb_id: integer() | nil,
            imdb_id: String.t() | nil,
            title: String.t() | nil,
            season_number: integer() | nil,
            episode_number: integer() | nil
          }

    defstruct tmdb_id: nil,
              tvdb_id: nil,
              imdb_id: nil,
              title: nil,
              season_number: nil,
              episode_number: nil
  end

  defmodule BookIdentity do
    @type t :: %__MODULE__{
            hardcover_id: integer() | nil,
            isbn: integer() | nil,
            title: String.t() | nil,
            author: String.t() | nil
          }

    defstruct hardcover_id: nil,
              isbn: nil,
              title: nil,
              author: nil
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

  @doc """
  Builds a fresh `Candidate` for a discovered file during `Scan`. `path` is expected to be absolute paths.
  """
  def new(path) do
    %__MODULE__{path: path}
  end
end

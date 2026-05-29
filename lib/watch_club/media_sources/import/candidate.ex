defmodule WatchClub.MediaSources.Import.Candidate do
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
      defstruct [:stream_index, :codec, :width, :height, :frame_rate, :bit_rate, default?: false]
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

  @doc """
  Flattens a `Candidate`'s scan-time fields (`path` and `identity`) into a
  plain map for an Oban job's args. `identity` is flattened with
  `Map.from_struct/1`, so no JSON encoder impl is required.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{path: path, identity: identity}) do
    %{path: path, identity: identity && Map.from_struct(identity)}
  end

  @doc """
  Rebuilds a `Candidate` from an Oban job's (string-keyed) args. The
  identity struct is chosen from `media_type`. Inverse of `to_map/1`.
  """
  @spec from_map(map(), atom()) :: t()
  def from_map(%{"path" => path, "identity" => nil}, _media_type) do
    %__MODULE__{path: path}
  end

  def from_map(%{"path" => path, "identity" => fields}, media_type) do
    module =
      case media_type do
        :movie -> __MODULE__.MovieIdentity
        :tv_show_episode -> __MODULE__.EpisodeIdentity
        type when type in [:ebook, :audiobook] -> __MODULE__.BookIdentity
      end

    # to_existing_atom: identity keys are struct fields, so the atoms exist.
    fields = Map.new(fields, fn {key, value} -> {String.to_existing_atom(key), value} end)

    %__MODULE__{path: path, identity: struct(module, fields)}
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%{path: path}), do: path
  end
end

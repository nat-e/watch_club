defmodule WatchClub.MediaSources.Import.Candidate do
  @moduledoc """
  A file that the pipeline is processing. Stages enrich the candidate with one
  field each as it flows through the pipeline; once every stage has run (or
  the pipeline halts).
  """

  @type t :: %__MODULE__{
          media_source_id: Ash.UUIDv7.t() | nil,
          path: String.t() | nil,
          media_type: atom() | nil,
          identity:
            __MODULE__.MovieIdentity.t()
            | __MODULE__.EpisodeIdentity.t()
            | __MODULE__.SportsEventIdentity.t()
            | __MODULE__.BookIdentity.t()
            | nil,
          media_structure: __MODULE__.MediaStructure.t() | nil,
          match_result: __MODULE__.MatchResult.t() | nil
        }

  defstruct [
    # The Media Source its Media belongs to, set when the file's ingest job is built
    :media_source_id,
    :path,
    :media_type,
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

  defmodule SportsEventIdentity do
    @moduledoc """
    A Sports Event by its Sportarr ID, or else by its title and year as found in a
    file name. The title may end with words that aren't in the event's title, such
    as "Prelims".
    """
    @type t :: %__MODULE__{
            sportarr_id: String.t() | nil,
            title: String.t() | nil,
            year: integer() | nil
          }

    defstruct sportarr_id: nil, title: nil, year: nil
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
        forced?: false
      ]
    end
  end

  @doc """
  Builds a fresh `Candidate` for a discovered file during `Scan`. `path` is
  expected to be an absolute path; `media_type` comes from the Media Source
  being scanned.
  """
  def new(path, media_type) do
    %__MODULE__{path: path, media_type: media_type}
  end

  @doc """
  Flattens a `Candidate`'s scan-time fields (`media_source_id`, `path`, `media_type`, and
  `identity`) into a plain map for an Oban job's args. `identity` is
  flattened with `Map.from_struct/1`, so no JSON encoder impl is required.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = candidate) do
    %{
      media_source_id: candidate.media_source_id,
      path: candidate.path,
      media_type: candidate.media_type,
      identity: candidate.identity && Map.from_struct(candidate.identity)
    }
  end

  @doc """
  Rebuilds a `Candidate` from an Oban job's (string-keyed) args. The
  identity struct is chosen from the serialized `media_type`. Inverse of
  `to_map/1`.
  """
  @spec from_map(map()) :: t()
  def from_map(%{
        "media_source_id" => media_source_id,
        "path" => path,
        "media_type" => media_type,
        "identity" => identity_fields
      }) do
    media_type = to_media_type(media_type)

    %__MODULE__{
      media_source_id: media_source_id,
      path: path,
      media_type: media_type,
      identity: build_identity(identity_fields, media_type)
    }
  end

  defp to_media_type(media_type) when is_atom(media_type), do: media_type

  defp to_media_type(media_type) when is_binary(media_type),
    do: String.to_existing_atom(media_type)

  defp build_identity(nil, _media_type), do: nil

  defp build_identity(fields, media_type) do
    module =
      case media_type do
        :movie -> __MODULE__.MovieIdentity
        :tv_show_episode -> __MODULE__.EpisodeIdentity
        :sports_event -> __MODULE__.SportsEventIdentity
        type when type in [:ebook, :audiobook] -> __MODULE__.BookIdentity
      end

    # to_existing_atom: identity keys are struct fields, so the atoms exist.
    fields = Map.new(fields, fn {key, value} -> {String.to_existing_atom(key), value} end)

    struct(module, fields)
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%{path: path}), do: path
  end
end

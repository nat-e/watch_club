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
          match_result: __MODULE__.MatchResult.t() | nil,
          regenerate_thumbnails_and_markers?: boolean()
        }

  defstruct [
    # The Media Source its Media belongs to, set when the file's ingest job is built
    :media_source_id,
    :path,
    :media_type,
    :relative_path,
    :identity,
    :media_structure,
    :match_result,
    # The Media Import's choice to rebuild them even when the file hasn't changed
    regenerate_thumbnails_and_markers?: false
  ]

  defmodule MatchResult do
    @moduledoc """
    The result of matching a file to its Content. With `result: :matched`, `parts` lists the
    Parts the file holds, each a map with a `movie_id`, `tv_show_episode_id` or `sports_event_id`
    and a `number`, and `reason` is `:manual_match` when they come from its Manual Match. With
    `:unmatched`, `parts` is empty and `reason` says why: no Content matches the file
    (`:content_not_found`), or its TV Show doesn't list one of its TV Show Episodes
    (`:episode_not_listed`). Nil until the file is matched.
    """

    @type t :: %__MODULE__{
            result: :matched | :unmatched,
            reason: :manual_match | :content_not_found | :episode_not_listed | nil,
            parts: [map()]
          }

    defstruct [:result, :reason, parts: []]
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
    @moduledoc """
    Identifies a TV Show, by its ids or else its `title`, and the `episodes` a file holds.

    Episode numbers and titles come from the source: Sonarr's, which follow TVDB, or the file
    name's for a filesystem Media Source. Sonarr also gives each episode's air date and TVDB id.
    """

    defmodule Episode do
      @moduledoc false
      @derive Jason.Encoder

      @type t :: %__MODULE__{
              season_number: integer() | nil,
              episode_number: integer() | nil,
              title: String.t() | nil,
              air_date: Date.t() | nil,
              tvdb_id: integer() | nil
            }

      defstruct [:season_number, :episode_number, :title, :air_date, :tvdb_id]
    end

    @type t :: %__MODULE__{
            tmdb_id: integer() | nil,
            tvdb_id: integer() | nil,
            imdb_id: String.t() | nil,
            title: String.t() | nil,
            episodes: [Episode.t()]
          }

    defstruct tmdb_id: nil,
              tvdb_id: nil,
              imdb_id: nil,
              title: nil,
              episodes: []
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
    text-track files for videos). A video also gets its File Fingerprint and its
    keyframes.
    """

    @type t :: %__MODULE__{}

    defstruct [
      :file_fingerprint,
      :container,
      :duration_seconds,
      :bit_rate,
      :keyframe_seconds,
      video_tracks: [],
      audio_tracks: [],
      text_tracks: []
    ]

    defmodule VideoTrack do
      @moduledoc false
      defstruct [
        :stream_index,
        :codec,
        :profile,
        :level,
        :width,
        :height,
        :frame_rate,
        :bit_rate,
        default?: false
      ]
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
  Turns a `Candidate`'s scan-time fields (`media_source_id`, `path`, `media_type`, `identity` and
  `regenerate_thumbnails_and_markers?`) into a map that can be stored as JSON. `from_map/1`
  reverses it.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = candidate) do
    %{
      media_source_id: candidate.media_source_id,
      path: candidate.path,
      media_type: candidate.media_type,
      identity: candidate.identity && Map.from_struct(candidate.identity),
      regenerate_thumbnails_and_markers?: candidate.regenerate_thumbnails_and_markers?
    }
  end

  @doc """
  Rebuilds a `Candidate` from an Oban job's (string-keyed) args. The
  identity struct is chosen from the serialized `media_type`. Inverse of
  `to_map/1`.
  """
  @spec from_map(map()) :: t()
  def from_map(
        %{
          "media_source_id" => media_source_id,
          "path" => path,
          "media_type" => media_type,
          "identity" => identity_fields
        } = args
      ) do
    media_type = to_media_type(media_type)

    %__MODULE__{
      media_source_id: media_source_id,
      path: path,
      media_type: media_type,
      identity: build_identity(identity_fields, media_type),
      # Missing from the jobs enqueued before the option existed
      regenerate_thumbnails_and_markers?:
        Map.get(args, "regenerate_thumbnails_and_markers?", false)
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

    case {module, atom_keys(fields)} do
      {__MODULE__.EpisodeIdentity, %{episodes: episodes} = fields} ->
        struct(module, %{fields | episodes: Enum.map(episodes, &episode/1)})

      # Jobs enqueued before `episodes` existed have one episode's numbers instead
      {__MODULE__.EpisodeIdentity, fields} ->
        episode = struct(__MODULE__.EpisodeIdentity.Episode, fields)
        struct(module, Map.put(fields, :episodes, [episode]))

      {module, fields} ->
        struct(module, fields)
    end
  end

  defp episode(fields) do
    fields = atom_keys(fields)

    struct(__MODULE__.EpisodeIdentity.Episode, %{
      fields
      | air_date: WatchClub.Helpers.maybe_date!(fields.air_date)
    })
  end

  # The keys are struct fields, so their atoms already exist
  defp atom_keys(fields),
    do: Map.new(fields, fn {key, value} -> {String.to_existing_atom(key), value} end)

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%{path: path}), do: path
  end
end

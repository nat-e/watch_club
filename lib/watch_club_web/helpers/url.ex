defmodule WatchClubWeb.Helpers.Url do
  alias WatchClub.Accounts.InvitationCode

  use Phoenix.VerifiedRoutes,
    endpoint: WatchClubWeb.Endpoint,
    router: WatchClubWeb.Router,
    statics: WatchClubWeb.static_paths()

  alias WatchClub.Contents.{Movie, TvShowEpisode}
  alias WatchClub.MediaCatalog.Video

  @type t :: %__MODULE__{
          scheme: String.t(),
          authority: String.t(),
          path: String.t(),
          query: %{String.t() => String.t()}
        }
  @enforce_keys [:scheme, :authority, :path, :query]
  defstruct [:scheme, :authority, :path, :query]

  @spec add_param(t(), String.t(), any()) :: t()
  def add_param(%__MODULE__{} = url, key, value) do
    %{url | query: Map.put(url.query, key, to_string(value))}
  end

  @spec remove_param(t(), String.t()) :: t()
  def remove_param(%__MODULE__{} = url, key) do
    %{url | query: Map.delete(url.query, key)}
  end

  @spec to_url(t(), absolute: boolean()) :: String.t()
  def to_url(
        %__MODULE__{scheme: scheme, authority: authority, path: path, query: query},
        opts \\ []
      ) do
    query_string = if query == %{}, do: "", else: "?" <> URI.encode_query(query)
    relative = path <> query_string

    if Keyword.get(opts, :absolute) do
      scheme <> "://" <> authority <> relative
    else
      relative
    end
  end

  @doc """
  Strips `http://` / `https://` from a URL for compact display.
  """
  @spec strip_scheme(String.t()) :: String.t()
  def strip_scheme(url) when is_binary(url) do
    url
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("http://", "")
  end

  @doc """
  Parses a URL param string into one of `allowed_values`, such as atoms or
  integers, falling back to `default`. Matches on each value's `to_string/1`
  rather than `String.to_atom/1`, so untrusted input never mints a new atom.
  """
  def parse_url_param(value, allowed_values, default \\ nil)
  def parse_url_param(nil, _allowed_values, default), do: default

  def parse_url_param(value, allowed_values, default) when is_binary(value) do
    Enum.find(allowed_values, default, &(to_string(&1) == value))
  end

  # A hand-edited URL can send a list, such as `type[]=movie`
  def parse_url_param(_value, _allowed_values, default), do: default

  @spec invitation_url(t(), InvitationCode.t()) :: t()
  def invitation_url(%__MODULE__{} = url, %InvitationCode{} = invitation) do
    %__MODULE__{
      scheme: url.scheme,
      authority: url.authority,
      path: ~p"/join",
      query: %{"code" => invitation.code}
    }
  end

  @spec reset_password_url(t(), String.t()) :: t()
  def reset_password_url(%__MODULE__{} = url, token) when is_binary(token) do
    %__MODULE__{
      scheme: url.scheme,
      authority: url.authority,
      path: ~p"/reset-password",
      query: %{"token" => token}
    }
  end

  @doc """
  Builds the callback URL Watch Club asks a request-capable Media
  Source to POST events to. Format is shared between wizard
  verification and webhook registration, so they must agree.
  """
  @spec webhook_callback_url(String.t(), atom() | String.t(), String.t()) :: String.t()
  def webhook_callback_url(base, source_type, media_source_id)
      when is_binary(base) and is_binary(media_source_id) do
    "#{base}/webhooks/#{source_type}/#{media_source_id}"
  end

  @doc """
  Whether `path` is the page at `section_path` or a page under it.
  """
  def in_section?(path, section_path),
    do: path == section_path or String.starts_with?(path, section_path <> "/")

  @doc """
  The search page for `query`, in the Library only when `has_media?`.
  """
  def search_link(query, has_media?, scope \\ :movies_and_shows) do
    params =
      [query: query] ++
        if(has_media?, do: [library: "1"], else: []) ++
        if(scope == :sports_events, do: [scope: "sports"], else: [])

    ~p"/search?#{params}"
  end

  @doc """
  The query, filter and scope of the search page's URL parameters, as `search_link/3` writes them.
  """
  def search_params(params) do
    %{
      query: String.trim(params["query"] || ""),
      has_media?: params["library"] == "1",
      scope: if(params["scope"] == "sports", do: :sports_events, else: :movies_and_shows)
    }
  end

  @doc """
  The Content page of a Movie or a TV Show, from its `Content` or its `ContentIdentity`.
  """
  def content_details_link(%{type: :movie, external_id: id}), do: ~p"/movies/#{id}"
  def content_details_link(%{type: :tv_show, external_id: id}), do: ~p"/shows/#{id}"
  def content_details_link(%{type: :sports_event, external_id: id}), do: ~p"/sports/#{id}"

  def player_link(%Movie{} = movie), do: ~p"/play/#{List.first(movie.videos).id}"
  def player_link(%TvShowEpisode{} = episode), do: ~p"/play/#{List.first(episode.videos).id}"
  def player_link([%Video{} = video | _]), do: ~p"/play/#{video.id}"
end

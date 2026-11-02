defmodule WatchClubWeb.Helpers.Url do
  alias WatchClub.Accounts.InvitationCode

  use Phoenix.VerifiedRoutes,
    endpoint: WatchClubWeb.Endpoint,
    router: WatchClubWeb.Router,
    statics: WatchClubWeb.static_paths()

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.{Content, ContentIdentity, Movie, TvShowEpisode}
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
  Parses a URL param string into one of `allowed_values` (a list of atoms),
  falling back to `default`. Matches on the stringified atom rather than
  `String.to_atom/1`, so untrusted input never mints a new atom.
  """
  def parse_url_param(value, allowed_values, default \\ nil)
  def parse_url_param(nil, _allowed_values, default), do: default

  def parse_url_param(value, allowed_values, default) when is_binary(value) do
    Enum.find(allowed_values, default, &(to_string(&1) == value))
  end

  @spec invitation_url(t(), InvitationCode.t()) :: t()
  def invitation_url(%__MODULE__{} = url, %InvitationCode{} = invitation) do
    %__MODULE__{
      scheme: url.scheme,
      authority: url.authority,
      path: ~p"/join/#{invitation.code}",
      query: %{}
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
    "#{WatchClub.Shared.Path.normalize_base_url(base)}/webhooks/#{source_type}/#{media_source_id}"
  end

  def list_link(list_id), do: ~p"/lists/#{list_id}"

  def content_details_link(%Content{type: type, external_id: id}),
    do: content_details_link(type, id, nil)

  def content_details_link(%ContentIdentity{type: type, external_id: id}),
    do: content_details_link(type, id, nil)

  def content_details_link(content_type, external_id, selected_club_id \\ nil)

  def content_details_link(:movie, external_id, selected_club_id),
    do: ~p"/movies/#{external_id}?#{content_details_params(selected_club_id)}"

  def content_details_link(:tv_show, external_id, selected_club_id),
    do: ~p"/shows/#{external_id}?#{content_details_params(selected_club_id)}"

  def player_link(%Movie{} = movie), do: ~p"/play/#{List.first(movie.videos).id}"
  def player_link(%TvShowEpisode{} = episode), do: ~p"/play/#{List.first(episode.videos).id}"
  def player_link([%Video{} = video | _]), do: ~p"/play/#{video.id}"

  def club_library_link(%Library{id: library_id, club_id: club_id}),
    do: ~p"/clubs/#{club_id}/libraries/#{library_id}"

  defp content_details_params(nil), do: %{}
  defp content_details_params(selected_club_id), do: %{selected_club_id: selected_club_id}
end

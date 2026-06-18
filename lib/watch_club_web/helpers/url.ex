defmodule WatchClubWeb.Helpers.Url do
  alias WatchClub.Accounts.InvitationCode

  use Phoenix.VerifiedRoutes,
    endpoint: WatchClubWeb.Endpoint,
    router: WatchClubWeb.Router,
    statics: WatchClubWeb.static_paths()

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

  @spec invitation_url(t(), InvitationCode.t()) :: t()
  def invitation_url(%__MODULE__{} = url, %InvitationCode{} = invitation) do
    %__MODULE__{
      scheme: url.scheme,
      authority: url.authority,
      path: ~p"/join/#{invitation.code}",
      query: %{}
    }
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
end

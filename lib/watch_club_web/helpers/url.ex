defmodule WatchClubWeb.Helpers.Url do
  alias WatchClub.Clubs.Invitation

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
  def to_url(%__MODULE__{authority: authority, path: path, query: query}, opts \\ []) do
    relative = path <> "?" <> URI.encode_query(query)

    if Keyword.get(opts, :absolute) do
      "https://" <> authority <> relative
    else
      relative
    end
  end

  @spec invitation_url(t(), Invitation.t()) :: t()
  def invitation_url(%__MODULE__{} = url, %Invitation{} = invitation) do
    %__MODULE__{
      scheme: url.scheme,
      authority: url.authority,
      path: ~p"/invitations/#{invitation.id}",
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
end

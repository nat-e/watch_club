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
          params: %{String.t() => String.t()}
        }
  @enforce_keys [:scheme, :authority, :path, :params]
  defstruct [:scheme, :authority, :path, :params]

  @spec add_param(t(), String.t(), any()) :: t()
  def add_param(%__MODULE__{} = url, key, value) do
    %{url | params: Map.put(url.params, key, to_string(value))}
  end

  @spec remove_param(t(), String.t()) :: t()
  def remove_param(%__MODULE__{} = url, key) do
    %{url | params: Map.delete(url.params, key)}
  end

  @spec to_url(t(), absolute: boolean()) :: String.t()
  def to_url(%__MODULE__{authority: authority, path: path, params: params}, opts \\ []) do
    relative = path <> "?" <> URI.encode_query(params)

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
      params: %{}
    }
  end
end

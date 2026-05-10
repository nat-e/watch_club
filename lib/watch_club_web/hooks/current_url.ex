defmodule WatchClubWeb.Hooks.CurrentUrl do
  import Phoenix.LiveView
  import Phoenix.Component

  alias WatchClubWeb.Helpers.Url

  @spec on_mount(:default, any(), any(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:set_current_url, :handle_params, &set_current_url/3)}
  end

  defp set_current_url(_params, uri, socket) do
    parsed = URI.parse(uri)

    {:cont,
     socket
     |> assign(:current_url, %Url{
       authority: parsed.authority,
       scheme: parsed.scheme,
       path: parsed.path,
       query: (is_nil(parsed.query) && %{}) || URI.decode_query(parsed.query)
     })}
  end
end

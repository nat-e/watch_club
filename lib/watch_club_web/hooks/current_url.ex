defmodule WatchClubWeb.Hooks.CurrentUrl do
  import Phoenix.LiveView
  import Phoenix.Component

  alias WatchClubWeb.Helpers.Url

  @spec on_mount(:default, any(), any(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:set_current_url, :handle_params, &set_current_url/3)
     |> attach_hook(:close_modal, :handle_info, &close_modal/2)}
  end

  defp set_current_url(params, uri, socket) do
    parsed = URI.parse(uri)

    {:cont,
     socket
     |> assign(:current_url, %Url{
       authority: parsed.authority,
       scheme: parsed.scheme,
       path: parsed.path,
       params: params
     })}
  end

  defp close_modal({:close_modal, modal_name, opts}, socket) do
    %{current_url: %Url{} = current_url} = socket.assigns
    new_url = current_url |> Url.remove_param(to_string(modal_name))

    new_url =
      case opts[:replace_with] do
        {new_modal_name, value} -> new_url |> Url.add_param(new_modal_name, value)
        _ -> new_url
      end

    {:halt, push_patch(socket, to: new_url |> Url.to_url())}
  end

  defp close_modal(_msg, socket), do: {:cont, socket}
end

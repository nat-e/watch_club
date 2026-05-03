defmodule WatchClubWeb.Hooks.Flash do
  import Phoenix.LiveView

  @spec on_mount(:default, any(), any(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:put_flash_message, :handle_info, &put_flash_message/2)}
  end

  defp put_flash_message({:put_flash, kind, message}, socket) do
    {:halt, put_flash(socket, kind, message)}
  end

  defp put_flash_message(_msg, socket), do: {:cont, socket}
end

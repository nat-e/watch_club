defmodule WatchClubWeb.Hooks.InstanceSettings do
  @moduledoc """
  A LiveView hook that loads the global instance settings and adds them to the socket assigns
  """
  import Phoenix.Component

  @spec on_mount(:default, any(), any(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    {:cont, socket |> assign(:instance_settings, WatchClub.Instance.get_instance_settings!())}
  end
end

defmodule WatchClubWeb.Plugs.InstanceSettings do
  @moduledoc """
  Assigns the instance settings to the conn so they are available during dead
  renders (the root layout title, error pages), mirroring how
  `WatchClubWeb.Hooks.InstanceSettings` loads them for LiveViews.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :instance_settings, WatchClub.Instance.get_instance_settings!())
  end
end

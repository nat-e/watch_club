defmodule WatchClubWeb.Components.UI.LucideIcon do
  @moduledoc """
  Dynamic Lucide icon renderer.
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :name, :any, required: true
  attr :rest, :global

  def lucide_icon(assigns) do
    icon_name =
      case Lucideicons.lookup_icon(assigns.name) do
        {:ok, icon} -> icon.name
        {:error, :not_found} -> :library
      end

    attrs = if assigns.class, do: Map.put(assigns.rest, :class, assigns.class), else: assigns.rest

    apply(Lucideicons, icon_name, [Map.put(attrs, :__changed__, nil)])
  end
end

defmodule WatchClubWeb.Components.UI.LucideIcon do
  @moduledoc """
  Dynamic Lucide icon renderer.
  """
  use Phoenix.Component

  @lucide_icon_names Lucideicons.icon_names()
  @lucide_icon_names_by_string Map.new(@lucide_icon_names, &{Atom.to_string(&1), &1})

  attr :class, :any, default: nil
  attr :name, :any, required: true
  attr :rest, :global

  def lucide_icon(assigns) do
    icon_name = normalize_icon_name(assigns.name)
    attrs = if assigns.class, do: Map.put(assigns.rest, :class, assigns.class), else: assigns.rest

    apply(Lucideicons, icon_name, [Map.put(attrs, :__changed__, nil)])
  end

  defp normalize_icon_name(name) when is_atom(name) and name in @lucide_icon_names, do: name

  defp normalize_icon_name(name) when is_binary(name) do
    Map.get(@lucide_icon_names_by_string, name, :library)
  end

  defp normalize_icon_name(_name), do: :library
end

defmodule WatchClub.Shared.LucideIcon do
  @names Lucideicons.icon_names() |> Enum.map(&Atom.to_string/1)

  def names, do: @names

  def valid?(icon_name) when is_binary(icon_name), do: icon_name in @names
  def valid?(_icon_name), do: false
end

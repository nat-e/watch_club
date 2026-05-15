defmodule WatchClub.Shared.SortOrder do
  @values [:asc, :desc]
  @param_values Map.new(@values, &{Atom.to_string(&1), &1})

  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: @values

  def parse_param(param) when is_binary(param), do: Map.fetch(@param_values, param)
  def parse_param(_param), do: :error

  def nils_last(:asc), do: :asc_nils_last
  def nils_last(:desc), do: :desc_nils_last

  def switch(:asc), do: :desc
  def switch(:desc), do: :asc

  def translated_label(:asc), do: dgettext("sort", "ascending")
  def translated_label(:desc), do: dgettext("sort", "descending")
end

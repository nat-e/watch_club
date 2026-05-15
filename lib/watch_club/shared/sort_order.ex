defmodule WatchClub.Shared.SortOrder do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [:asc, :desc]

  def nils_last(:asc), do: :asc_nils_last
  def nils_last(:desc), do: :desc_nils_last

  def switch(:asc), do: :desc
  def switch(:desc), do: :asc

  def translated_label(:asc), do: dgettext("sort", "ascending")
  def translated_label(:desc), do: dgettext("sort", "descending")
end

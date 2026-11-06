defmodule WatchClub.Contents.LibrarySort do
  @moduledoc """
  The orders Browse shows the Library in (`Content.in_library`). `translated_label/1` drives its
  sort menu.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum, values: [:recently_added, :best_rated, :newest, :oldest, :title]

  def default, do: :recently_added

  def translated_label(:recently_added), do: dgettext("library_sorts", "Recently added")
  def translated_label(:best_rated), do: dgettext("library_sorts", "Best rated")
  def translated_label(:newest), do: dgettext("library_sorts", "Newest")
  def translated_label(:oldest), do: dgettext("library_sorts", "Oldest")
  def translated_label(:title), do: dgettext("library_sorts", "Title, A to Z")
end

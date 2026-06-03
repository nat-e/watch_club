defmodule WatchClub.History.WatchStatus do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [:not_started, :in_progress, :completed]

  def translated_label(:not_started), do: dgettext("watch_statuses", "Not Watched")
  def translated_label(:in_progress), do: dgettext("watch_statuses", "Watching")
  def translated_label(:completed), do: dgettext("watch_statuses", "Watched")
end

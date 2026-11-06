defmodule WatchClub.Requests.ContentRequestStatus do
  @moduledoc """
  A Content Request Status, derived at read time by `ContentRequest`'s `status` calculation
  from the Content's Media and its best Media Source Request. `translated_label/1` names it in
  a word or two.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      # No Media Source Request yet, or still searching within the grace window
      :queued,
      :downloading,
      # Downloaded by the Media Source, but its Media isn't in WatchClub yet
      :importing,
      :not_released,
      # Still searching after the grace window
      :not_found,
      :failed,
      :completed
    ]

  def translated_label(:queued), do: dgettext("content_request_statuses", "Queued")
  def translated_label(:downloading), do: dgettext("content_request_statuses", "Downloading")
  def translated_label(:importing), do: dgettext("content_request_statuses", "Almost ready")
  def translated_label(:not_released), do: dgettext("content_request_statuses", "Not released")
  def translated_label(:not_found), do: dgettext("content_request_statuses", "Not found")
  def translated_label(:failed), do: dgettext("content_request_statuses", "Failed")
  def translated_label(:completed), do: dgettext("content_request_statuses", "Completed")
end

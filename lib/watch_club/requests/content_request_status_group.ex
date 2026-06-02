defmodule WatchClub.Requests.ContentRequestStatusGroup do
  @moduledoc """
  The coarse, UI-level grouping of a `ContentRequestStatus`, used by the
  My Requests page filter.

  The card still shows the fine-grained status (queued / downloading X% /
  importing); this collapses the three in-flight statuses into `:in_progress`,
  and `:not_released` + `:not_found` into `:not_released`. Derived at read time
  by `ContentRequest`'s `status_group` calculation.

  Declared in display order, with `translated_label/1` for the UI (same
  convention as `ContentRequestStatus` / `Contents.ContentType`).
  """
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum, values: [:in_progress, :completed, :failed, :not_released]

  def translated_label(nil), do: dgettext("content_request_status_groups", "All")
  def translated_label(:in_progress), do: dgettext("content_request_status_groups", "In progress")
  def translated_label(:completed), do: dgettext("content_request_status_groups", "Completed")
  def translated_label(:failed), do: dgettext("content_request_status_groups", "Failed")

  def translated_label(:not_released),
    do: dgettext("content_request_status_groups", "Not released")
end

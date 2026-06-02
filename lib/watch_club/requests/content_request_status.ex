defmodule WatchClub.Requests.ContentRequestStatus do
  @moduledoc """
  The **displayed** status of a `ContentRequest` on the My Requests page.

  A Content Request has no stored status — this value is computed at read
  time (see `ContentRequest`'s `status` calculation) from the request's
  `MediaSourceRequest`s + the Content's Media + time. It is declared as an
  enum so the calculation type-checks, with `translated_label/1` for the UI
  (same convention as `Contents.ContentType` / `MediaCatalog.MediaType`).

  Distinct from `MediaSourceRequest`'s stored `state`: that is one upstream
  request's progress; this is the user-facing rollup across all of them.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      :not_released,
      :not_found,
      :requested,
      :downloading,
      :importing,
      :completed,
      :failed
    ]

  def translated_label(:not_released), do: dgettext("content_request_statuses", "Not released")
  def translated_label(:not_found), do: dgettext("content_request_statuses", "Not found")
  def translated_label(:requested), do: dgettext("content_request_statuses", "Queued")
  def translated_label(:downloading), do: dgettext("content_request_statuses", "Downloading")
  def translated_label(:importing), do: dgettext("content_request_statuses", "Importing")
  def translated_label(:completed), do: dgettext("content_request_statuses", "Completed")
  def translated_label(:failed), do: dgettext("content_request_statuses", "Failed")
end

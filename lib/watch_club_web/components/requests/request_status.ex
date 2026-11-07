defmodule WatchClubWeb.Components.Requests.RequestStatus do
  @moduledoc """
  When a requested Content can be watched: an icon for its Content Request Status, a few words,
  and a bar while it downloads. My Requests, Playlist Items and the Content page show it.
  """
  use WatchClubWeb, :component

  attr :request, ContentRequest, required: true, doc: "with its `status` and `download_progress`"
  attr :release_date, Date, default: nil, doc: "the Content's, for when it's not released yet"
  attr :locale, :atom, required: true, doc: "a `UserLocale`"
  attr :rest, :global

  def request_status(assigns) do
    ~H"""
    <span class="flex min-w-0 flex-col" {@rest}>
      <span class="flex gap-tight text-sm text-text-muted">
        <span class="flex h-lh shrink-0 items-center">
          <.status_icon status={@request.status} />
        </span>
        {when_watchable(@request, @release_date, @locale)}
      </span>
      <.progress_bar
        :if={@request.status == :downloading}
        percent={@request.download_progress}
        class="mt-related max-w-48"
      />
    </span>
    """
  end

  attr :status, :atom, required: true, doc: "a `ContentRequestStatus`"

  defp status_icon(assigns) do
    ~H"""
    <Lucideicons.download
      :if={@status in [:importing, :downloading]}
      class="size-icon-sm shrink-0 text-accent"
    />
    <Lucideicons.search :if={@status == :searching} class="size-icon-sm shrink-0 text-text-subtle" />
    <Lucideicons.calendar
      :if={@status == :not_released}
      class="size-icon-sm shrink-0 text-text-subtle"
    />
    <Lucideicons.search_x :if={@status == :not_found} class="size-icon-sm shrink-0 text-text-subtle" />
    <Lucideicons.circle_alert :if={@status == :failed} class="size-icon-sm shrink-0 text-danger" />
    """
  end

  defp when_watchable(%ContentRequest{status: status}, _release_date, _locale)
       when status in [:importing, :searching],
       do: ContentRequestStatus.translated_label(status)

  defp when_watchable(%ContentRequest{status: :downloading} = request, _release_date, _locale),
    do: dgettext("requests", "%{percent}% downloaded", percent: round(request.download_progress))

  # TMDB's date is often the cinema release, before the one we can download
  defp when_watchable(%ContentRequest{status: :not_released}, release_date, locale) do
    if release_date && Date.after?(release_date, Date.utc_today()),
      do: dgettext("requests", "Out on %{date}", date: Time.long_date(release_date, locale)),
      else: dgettext("requests", "Not released yet")
  end

  defp when_watchable(%ContentRequest{status: :not_found}, _release_date, _locale),
    do: dgettext("requests", "Not found, we'll keep looking for it")

  defp when_watchable(%ContentRequest{status: :failed}, _release_date, _locale),
    do: dgettext("requests", "There was a problem, the instance administrator was told")
end

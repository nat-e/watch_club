defmodule WatchClubWeb.MyRequestsPage.RequestOnTheWay do
  @moduledoc """
  A Content Request on the way, in My Requests' list: its poster and its name, which open its
  Content, when it can be watched, and ✕ to Stop Getting Notified.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  attr :request, ContentRequest, required: true

  attr :focus_after_removal, :string,
    required: true,
    doc: "the id of what gets the focus once the User stops getting notified"

  attr :locale, :atom, required: true

  def request_on_the_way(assigns) do
    assigns =
      assigns
      |> assign(:title, assigns.request.content.implementation.best_localization.title)
      |> assign(
        :path,
        Url.content_details_link(ContentIdentity.from_content(assigns.request.content))
      )

    ~H"""
    <li id={"request-on-the-way-#{@request.id}"} class="flex items-center gap-group">
      <%!-- Screen readers and keyboards reach the name's link --%>
      <.link navigate={@path} tabindex="-1" aria-hidden="true" class="shrink-0">
        <.tmdb_poster
          path={@request.content.implementation.best_localization.poster_path}
          size="w154"
          class="w-20"
        />
      </.link>
      <div class="flex min-w-0 flex-1 flex-col">
        <.link navigate={@path} class="line-clamp-2 text-lg font-semibold hover:underline">
          {@title}
        </.link>
        <span class="flex gap-tight text-sm text-text-muted">
          <span class="flex h-lh shrink-0 items-center">
            <.status_icon status={@request.status} />
          </span>
          {when_watchable(@request, @locale)}
        </span>
        <.progress_bar
          :if={@request.status == :downloading}
          percent={@request.download_progress}
          class="mt-related max-w-48"
        />
      </div>
      <.button
        id={"stop-getting-notified-#{@request.id}"}
        variant="ghost"
        size="icon-sm"
        aria-label={dgettext("requests", "Stop getting notified about %{title}", title: @title)}
        title={dgettext("requests", "Stop getting notified")}
        phx-click={
          JS.push("stop-getting-notified", value: %{id: @request.id})
          |> JS.focus(to: "##{@focus_after_removal}")
        }
        class="pointer-coarse:size-touch-target!"
      >
        <Lucideicons.x />
      </.button>
    </li>
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

  defp when_watchable(%ContentRequest{status: status}, _locale)
       when status in [:importing, :searching],
       do: ContentRequestStatus.translated_label(status)

  defp when_watchable(%ContentRequest{status: :downloading} = request, _locale),
    do: dgettext("requests", "%{percent}% downloaded", percent: round(request.download_progress))

  # TMDB's date is often the cinema release, before the one we can download
  defp when_watchable(%ContentRequest{status: :not_released} = request, locale) do
    release_date = request.content.release_date

    if release_date && Date.after?(release_date, Date.utc_today()) do
      dgettext("requests", "Out on %{date}", date: Time.long_date(release_date, locale))
    else
      dgettext("requests", "Not released yet")
    end
  end

  defp when_watchable(%ContentRequest{status: :not_found}, _locale),
    do: dgettext("requests", "Not found, we'll keep looking for it")

  defp when_watchable(%ContentRequest{status: :failed}, _locale),
    do: dgettext("requests", "There was a problem, the instance administrator was told")
end

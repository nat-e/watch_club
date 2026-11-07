defmodule WatchClubWeb.MyRequestsPage.RequestOnTheWay do
  @moduledoc """
  A Content Request on the way, in My Requests' list: its poster and its name, which open its
  Content, when it can be watched, and ✕ to Stop Getting Notified.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Requests.RequestStatus, only: [request_status: 1]

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
        <.request_status
          request={@request}
          release_date={@request.content.release_date}
          locale={@locale}
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
end

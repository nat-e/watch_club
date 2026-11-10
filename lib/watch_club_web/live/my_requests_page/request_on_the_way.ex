defmodule WatchClubWeb.MyRequestsPage.RequestOnTheWay do
  @moduledoc """
  A Content Request on the way, in My Requests' list: its poster and its name, which open its
  Content, when it can be watched, and ✕ to Stop Getting Notified. Play shows over its poster
  once its Content is Ready to Play.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Requests.RequestStatus, only: [request_status: 1]

  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive

  attr :request, ContentRequest,
    required: true,
    doc: "with what `request_status/1` needs, and its Content's `actor_ready_to_play?`"

  attr :focus_after_removal, :string,
    required: true,
    doc: "the id of what gets the focus once the User stops getting notified"

  attr :current_user, User, required: true

  def request_on_the_way(assigns) do
    assigns =
      assigns
      |> assign(:title, assigns.request.content.implementation.best_localization.title)
      |> assign(:content_identity, ContentIdentity.from_content(assigns.request.content))
      |> assign(
        :path,
        Url.content_details_link(ContentIdentity.from_content(assigns.request.content))
      )

    ~H"""
    <li id={"request-on-the-way-#{@request.id}"} class="flex items-center gap-group">
      <div class="relative shrink-0">
        <%!-- Screen readers and keyboards reach the name's link --%>
        <.link navigate={@path} tabindex="-1" aria-hidden="true" class="block">
          <.tmdb_poster
            path={@request.content.implementation.best_localization.poster_path}
            size="w154"
            class="w-20"
          />
        </.link>
        <div
          :if={@request.content.actor_ready_to_play?}
          class="absolute inset-0 grid place-items-center"
        >
          <.live_component
            id={PlayOrRequestButtonLive.dom_id(@content_identity)}
            module={PlayOrRequestButtonLive}
            content_identity={@content_identity}
            current_user={@current_user}
            variant="poster"
          />
        </div>
      </div>
      <div class="flex min-w-0 flex-1 flex-col">
        <.link navigate={@path} class="line-clamp-2 text-lg font-semibold hover:underline">
          {@title}
        </.link>
        <.request_status
          request={@request}
          release_date={@request.content.release_date}
          locale={@current_user.settings.locale}
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

defmodule WatchClubWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Navigation.AppBar
  import WatchClubWeb.Components.Navigation.Sidebar
  import WatchClubWeb.Components.Navigation.TabBar
  import WatchClubWeb.Components.Playbacks.TvBar

  alias WatchClub.Accounts.User
  alias WatchClub.Instance.InstanceSettings
  alias WatchClubWeb.Helpers.Url

  @doc """
  The main app layout, used on most screens.

  The bar at the top shows the page's name, its back button and, with `search`, the search field.
  A page is one of:

  - a top page, such as Browse: no back button.
  - a child page, such as a library: it gives its `:parent`, and back goes to it.
  - a Content page, the page of a movie or TV Show: set `content_page?`. The page lays out its
    own full-bleed hero, without the page padding, and the hero holds its visible `h1`, marked
    `data-page-title`. The bar sits transparent over the hero and shows the title once the `h1`
    scrolls away. Back goes to the previous page, or Browse.

  Other pages don't render an `h1`: the layout renders the title as one for screen readers.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_url, Url, required: true, doc: "the url of the current page"
  attr :class, :any, default: nil, doc: "classes of the page, except on a Content page"

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "cluster",
    doc: "the space between the page's children, except on a Content page"

  attr :current_user, User, required: true, doc: "the currently logged in user"

  attr :instance_settings, InstanceSettings,
    required: true,
    doc: "the instance configuration, e.g. its display name"

  attr :title, :string, required: true, doc: "the page's name"
  attr :content_page?, :boolean, default: false, doc: "the page of a movie or TV Show"
  attr :search, :boolean, default: false, doc: "shows the search field in the bar"

  attr :full_screen?, :boolean,
    default: false,
    doc: "on phones, hides the bar and the tabs, as an open Conversation does"

  attr :app_bar?, :boolean,
    default: true,
    doc: "shows the bar at the top. Without it, the page draws its own header and padding"

  attr :playback_session, :any,
    required: true,
    doc: "the User's Playback Session while it plays on a TV, which the TV bar shows, or nil"

  attr :tv_bar?, :boolean, default: true, doc: "shows the TV bar, unless the page is the Remote"

  slot :inner_block, required: true

  slot :hero,
    doc: """
    Full-width content between the bar and the page, outside the page's padding. The page paints
    above it, so a negative bottom margin slides the page over the hero's bottom.
    """

  slot :parent, doc: "the page this page belongs to" do
    attr :navigate, :string, required: true
    attr :label, :string, required: true
    attr :patch, :boolean, doc: "patches the LiveView, for a parent that is the same page"

    attr :narrow_only, :boolean,
      doc: "only on narrow screens, where a split view doesn't show the parent beside it"
  end

  def app(assigns) do
    assigns = assign(assigns, :tv_bar_session, assigns.tv_bar? && assigns.playback_session)

    ~H"""
    <div
      id="app-shell"
      class={
        [
          "min-h-svh bg-canvas text-text [--wc-app-bar-height:var(--wc-size-row-lg)] [--wc-sidebar-width:16rem] [--wc-tab-bar-height:var(--wc-size-row-lg)]",
          # On desktop, as tall as the sidebar's account menu beside it: its avatar and its two
          # lines, and their padding
          @tv_bar_session &&
            "[--wc-tv-bar-height:var(--wc-size-row-lg)] md:[--wc-tv-bar-height:calc(4*var(--wc-space-related)+2.25rem)]",
          !@tv_bar_session && "[--wc-tv-bar-height:0px]",
          # The bars docked at the bottom of the screen, which the page and the toasts stay above
          "[--wc-bottom-bars-height:calc(var(--wc-tab-bar-height)+var(--wc-tv-bar-height))] md:[--wc-bottom-bars-height:var(--wc-tv-bar-height)]",
          @full_screen? && "max-md:[--wc-bottom-bars-height:0px]"
        ]
      }
    >
      <.sidebar
        current_path={@current_url.path}
        current_user={@current_user}
        instance_settings={@instance_settings}
      />

      <%!-- Pages lay out by the main column's width, which leaves out the sidebar --%>
      <div class="@container/main pb-(--wc-bottom-bars-height) md:pl-(--wc-sidebar-width)">
        <.app_bar
          :if={@app_bar?}
          title={@title}
          content_page?={@content_page?}
          parent={@parent}
          search={@search}
          current_url={@current_url}
          current_user={@current_user}
          class={@full_screen? && "max-md:hidden"}
        />

        <main class={["relative", @content_page? && "-mt-(--wc-app-bar-height)"]}>
          <h1 :if={!@content_page? and @app_bar?} class="sr-only">{@title}</h1>
          {render_slot(@hero)}
          <%!-- A Content page lays out its own full-bleed hero --%>
          <div :if={@content_page? or !@app_bar?} class="relative z-1">
            {render_slot(@inner_block)}
          </div>
          <.page
            :if={!@content_page? and @app_bar?}
            width="full"
            space={@space}
            class={["relative z-1", @class]}
          >
            {render_slot(@inner_block)}
          </.page>
        </main>
      </div>

      <.tab_bar
        current_path={@current_url.path}
        current_user={@current_user}
        class={@full_screen? && "max-md:hidden"}
      />

      <.tv_bar
        :if={@tv_bar_session}
        session={@tv_bar_session}
        current_user={@current_user}
        class={@full_screen? && "max-md:hidden"}
      />

      <.flash flash={@flash} />
    </div>
    """
  end

  @doc """
  A layout displaying content in a centered card with a movie poster image fader background.
  Mainly used for authentication screens.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :title, :string, default: nil
  attr :class, :list, default: nil
  slot :inner_block, required: true

  def centered_card(assigns) do
    ~H"""
    <div class="relative grid min-h-svh place-items-center bg-canvas px-page py-page-y">
      <div class="relative z-10 w-full max-w-sm sm:max-w-md">
        <.card padding="cluster" class="flex flex-col gap-cluster">
          <h1
            :if={@title}
            class="inline-flex items-center gap-related font-heading text-xl font-semibold"
          >
            {@title}
          </h1>
          <.stack space="cluster" class={@class}>
            {render_slot(@inner_block)}
          </.stack>
        </.card>
      </div>
    </div>

    <.flash flash={@flash} />
    """
  end

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang={Gettext.get_locale(WatchClubWeb.Gettext)} class="theme-wc dark">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <.live_title default={@instance_settings.name}>
          {assigns[:page_title]}
        </.live_title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
        </script>
        {Application.get_env(:live_debugger, :live_debugger_tags)}
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end

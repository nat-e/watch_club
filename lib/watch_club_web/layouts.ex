defmodule WatchClubWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Navigation.AppBar
  import WatchClubWeb.Components.Navigation.Sidebar
  import WatchClubWeb.Components.Navigation.TabBar

  alias WatchClubWeb.Components.Clubs.ClubDialogsLive
  alias WatchClubWeb.Components.Lists.ListDialogsLive

  alias WatchClub.Accounts.User
  alias WatchClub.Instance.InstanceSettings
  alias WatchClubWeb.Helpers.Url

  @doc """
  The main app layout, used on most screens.

  The bar at the top shows the page's name and its back button. A page is one of:

  - a top page, such as Home or a club: no back button.
  - a child page, such as a library: it gives its `:parent`. The bar shows a breadcrumb, and back
    goes to the parent.
  - a Content page, the page of a movie or TV Show: set `content_page?`. The page lays out its
    own full-bleed hero, without the page padding, and the hero holds its visible `h1`, marked
    `data-page-title`. The bar sits transparent over the hero and shows the title once the `h1`
    scrolls away. Back goes to the previous page, or Home.

  Other pages don't render an `h1`: the layout renders the title as one for screen readers.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_url, Url, required: true, doc: "the url of the current page"
  attr :class, :any, default: nil, doc: "classes of the page, except on a Content page"

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "cluster",
    doc: "the space between the page's children, except on a Content page"

  attr :current_user, User,
    required: true,
    doc: "the currently logged in user, with their club memberships"

  attr :instance_settings, InstanceSettings,
    required: true,
    doc: "the instance configuration, e.g. its display name"

  attr :title, :string, required: true, doc: "the page's name"
  attr :content_page?, :boolean, default: false, doc: "the page of a movie or TV Show"

  slot :inner_block, required: true

  slot :hero,
    doc: "Full-width content between the bar and the page, outside the page's padding"

  slot :icon, doc: "the page's icon, before its name in the bar"

  slot :parent, doc: "the page this page belongs to; its inner block is the parent's icon" do
    attr :navigate, :string, required: true
    attr :label, :string, required: true
  end

  def app(assigns) do
    ~H"""
    <div
      id="app-shell"
      class="min-h-svh bg-canvas text-text [--wc-app-bar-height:var(--wc-size-row-md)] [--wc-sidebar-width:16rem] [--wc-tab-bar-height:var(--wc-size-row-lg)] md:[--wc-app-bar-height:var(--wc-size-row-lg)]"
    >
      <.sidebar
        current_path={@current_url.path}
        current_user={@current_user}
        instance_settings={@instance_settings}
      />

      <div class="pb-(--wc-tab-bar-height) md:pb-0 md:pl-(--wc-sidebar-width)">
        <.app_bar
          title={@title}
          content_page?={@content_page?}
          icon={@icon}
          parent={@parent}
          current_url={@current_url}
          current_user={@current_user}
          instance_settings={@instance_settings}
        />

        <main class={["relative", @content_page? && "-mt-(--wc-app-bar-height)"]}>
          <h1 :if={!@content_page?} class="sr-only">{@title}</h1>
          {render_slot(@hero)}
          <%!-- A Content page lays out its own full-bleed hero --%>
          <div :if={@content_page?} class="relative z-1">{render_slot(@inner_block)}</div>
          <.page :if={!@content_page?} width="full" space={@space} class={["relative z-1", @class]}>
            {render_slot(@inner_block)}
          </.page>
        </main>
      </div>

      <.tab_bar current_path={@current_url.path} />
    </div>

    <.live_component
      id={ClubDialogsLive.dom_id()}
      module={ClubDialogsLive}
      current_user={@current_user}
    />
    <.live_component
      id={ListDialogsLive.dom_id()}
      module={ListDialogsLive}
      current_user={@current_user}
    />
    <.flash flash={@flash} />
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

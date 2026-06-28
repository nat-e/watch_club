defmodule WatchClubWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WatchClubWeb, :component

  alias WatchClub.Accounts.User
  alias WatchClub.Instance.InstanceSettings
  alias WatchClubWeb.Helpers.Url

  @doc """
  The main app layout, used on most screens.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_url, Url, required: true, doc: "the url of the current page"
  attr :class, :any, default: nil
  attr :space, :string, values: ~w(none tight related group cluster section), default: "cluster"

  attr :current_user, User,
    required: true,
    doc: "the currently logged in user, with their club memberships"

  attr :instance_settings, InstanceSettings,
    required: true,
    doc: "the instance configuration, e.g. its display name"

  slot :inner_block, required: true

  slot :backdrop

  def app(assigns) do
    ~H"""
    <div class="min-h-svh bg-canvas text-text [--wc-sidebar-width:16rem]">
      <.live_component
        id="sidebar"
        module={WatchClubWeb.Components.Navigation.SidebarLive}
        current_url={@current_url}
        current_user={@current_user}
        instance_settings={@instance_settings}
      />

      <main class="relative min-h-svh md:pl-[var(--wc-sidebar-width)]">
        <div
          :if={@backdrop != []}
          class="absolute z-0 h-[400px] w-full bg-canvas xl:h-[500px]"
        >
          {render_slot(@backdrop)}
          <div class="to-canvas from-canvas/50 absolute inset-0 bg-linear-to-b"></div>
        </div>
        <.live_component
          id="navbar"
          module={WatchClubWeb.Components.Navigation.NavbarLive}
          current_url={@current_url}
          current_user={@current_user}
          instance_settings={@instance_settings}
        />
        <.page width="full" space={@space} class={["relative z-1", @class]}>
          {render_slot(@inner_block)}
        </.page>
      </main>
    </div>

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
            class="inline-flex items-center gap-related font-heading text-xl font-medium"
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

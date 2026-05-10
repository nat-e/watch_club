defmodule WatchClubWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use WatchClubWeb, :controller
      use WatchClubWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: WatchClubWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      use WatchClubWeb.Components
      alias WatchClubWeb.Layouts
      alias WatchClubWeb.Modals

      unquote(html_helpers())

      # Overridable no-op handle_params to allow patch from any LiveView
      @impl true
      def handle_params(_params, _uri, socket), do: {:noreply, socket}
      defoverridable handle_params: 3

      # Overridable no-op handle_info to avoid warnings when not defined
      @impl true
      def handle_info(_msg, socket), do: {:noreply, socket}
      defoverridable handle_info: 2
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      use WatchClubWeb.Components

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      use WatchClubWeb.Components

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: WatchClubWeb.Gettext

      # Gettext helpers
      import WatchClubWeb.Gettext.Helpers

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      use Shadcn.Components

      # Common modules used in templates
      alias Phoenix.LiveView.JS

      # Import domains and basic models
      alias WatchClub.{Accounts, Clubs, Contents}
      alias WatchClub.Accounts.User
      alias WatchClub.Clubs.{Club, Invitation, Library, Membership}
      alias WatchClub.Contents.{Book, Content, ContentType, Movie, SearchContentType, TvShow}

      alias WatchClubWeb.Helpers.Url

      # Allow Logger calls
      require Logger

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: WatchClubWeb.Endpoint,
        router: WatchClubWeb.Router,
        statics: WatchClubWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

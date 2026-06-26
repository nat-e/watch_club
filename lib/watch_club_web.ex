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
      alias WatchClubWeb.Layouts

      unquote(html_helpers())
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

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

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
      use WatchClubWeb.Components.UI

      alias Ash.Notifier.Notification

      # Common modules used in templates
      alias Phoenix.LiveView.JS

      # Import domains and basic models
      alias WatchClub.{
        Accounts,
        ActivityFeed,
        Clubs,
        Contents,
        History,
        Lists,
        MediaCatalog,
        MediaSources,
        Playbacks,
        Requests
      }

      alias WatchClub.Accounts.{InvitationCode, User, UserLocale, UserSettings}
      alias WatchClub.ActivityFeed.FeedEventScope

      alias WatchClub.ActivityFeed.Events.{
        ClubCreatedEvent,
        ContentAddedEvent,
        ContentWatchedEvent,
        LibraryCreatedEvent,
        MemberAddedEvent
      }

      alias WatchClub.Clubs.{Club, Library, LibraryItem, Membership, MembershipRole}

      alias WatchClub.Contents.{
        Book,
        Content,
        ContentIdentity,
        ContentType,
        ExternalIdSource,
        Movie,
        SearchContentType,
        TvShow,
        TvShowEpisode
      }

      alias WatchClub.History.{WatchProgress, WatchStatus}
      alias WatchClub.Lists.{ContentList, ListItem}

      alias WatchClub.MediaCatalog.{
        Audiobook,
        Ebook,
        Media,
        MediaType,
        Video,
        VideoResolution,
        VideoTrack
      }

      alias WatchClub.MediaSources.{Filesystem, Import, Servarr, Source}
      alias WatchClub.Playbacks.{Playback, Session}

      alias WatchClub.Requests.{
        ContentRequest,
        ContentRequestStatus,
        ContentRequestStatusGrup,
        MediaSourceRequest,
        MediaSourceRequestState
      }

      alias WatchClubWeb.Helpers.{Time, Url}

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

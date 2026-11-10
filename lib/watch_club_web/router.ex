defmodule WatchClubWeb.Router do
  use WatchClubWeb, :router

  use Phoenix.VerifiedRoutes,
    endpoint: WatchClubWeb.Endpoint,
    router: WatchClubWeb.Router,
    statics: WatchClubWeb.static_paths()

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers
  import PhoenixStorybook.Router

  alias WatchClub.Accounts.User

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WatchClubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :ensure_administrator_setup
    plug WatchClubWeb.Plugs.BrowserLocale
    plug WatchClubWeb.Plugs.InstanceSettings
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  # Inbound webhooks from media sources. JSON only; no session, no
  # CSRF, no Ash actor — handlers authenticate per-request from the
  # body or a header.
  pipeline :webhook do
    plug :accepts, ["json"]
  end

  # Media bytes for a signed-in User: the Player's HLS requests and Downloads.
  # Like :browser but without CSRF protection — the Player's HLS segment GETs
  # don't carry a CSRF token. No HTML rendering either,
  # so :accepts, layouts, and flash are intentionally absent.
  pipeline :playback do
    plug :fetch_session
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :ensure_administrator_setup
    plug :require_current_user
  end

  # For the Docker healthcheck and uptime monitoring. No pipeline, so it
  # answers before the administrator is set up.
  scope "/", WatchClubWeb do
    get "/health", HealthController, :show
  end

  scope "/webhooks", WatchClubWeb.Webhooks do
    pipe_through :webhook

    post "/radarr/:media_source_id", ServarrController, :handle
    post "/sonarr/:media_source_id", ServarrController, :handle
  end

  scope "/player", WatchClubWeb do
    pipe_through :playback

    get "/hls/:playback_id/master.m3u8", PlayerController, :master_playlist
    get "/hls/:playback_id/video/:variant/index.m3u8", PlayerController, :video_playlist
    get "/hls/:playback_id/audio/:track_id/index.m3u8", PlayerController, :audio_playlist
    get "/hls/:playback_id/subtitles/:track_id/index.m3u8", PlayerController, :subtitle_playlist
    get "/hls/:playback_id/video/:variant/:segment", PlayerController, :video_segment
    get "/hls/:playback_id/audio/:track_id/:segment", PlayerController, :audio_segment
    get "/hls/:playback_id/subtitles/:track_id/:file", PlayerController, :subtitle_file
    get "/thumbnails/:playback_id/:file", PlayerController, :thumbnails_file
  end

  scope "/media", WatchClubWeb do
    pipe_through :playback

    get "/:media_id/download", DownloadController, :download
  end

  scope "/", WatchClubWeb do
    pipe_through :browser

    ash_authentication_live_session :administrator_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_administrator_required},
        WatchClubWeb.Hooks.Conversations,
        WatchClubWeb.Hooks.Locale,
        WatchClubWeb.Hooks.InstanceSettings
      ] do
      live "/admin/settings", Admin.InstanceSettingsPage
      live "/admin/users", Admin.UsersPage
      live "/admin/media", Admin.MediaBrowserPage
      live "/admin/media/sources", Admin.MediaSourcesPage
      live "/admin/media/sources/:id/history", Admin.MediaSourceHistoryPage
      live "/admin/problem-reports", Admin.ProblemReportsPage
      live "/admin/problem-reports/:problem_report_id", Admin.ProblemReportsPage
    end

    ash_authentication_live_session :authenticated_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_user_required},
        WatchClubWeb.Hooks.Conversations,
        WatchClubWeb.Hooks.Locale,
        WatchClubWeb.Hooks.TimeZone,
        WatchClubWeb.Hooks.InstanceSettings
      ] do
      live "/", HomePage
      live "/browse", BrowsePage

      if Application.compile_env(:watch_club, :dev_routes) do
        live "/dev", Dev.IndexPage, :home
        live "/dev/prototypes", Dev.IndexPage, :prototypes
        live "/dev/prototypes/:prototype/*page", Dev.PrototypePage
      end

      live "/play/:media_id", PlayerPage
      live "/search", SearchPage
      live "/settings", Accounts.SettingsPage
      live "/my-requests", MyRequestsPage
      live "/inbox", Conversations.InboxPage
      live "/inbox/:conversation_id", Conversations.InboxPage
      live "/playlists", Playlists.PlaylistsPage
      live "/playlists/:playlist_id", Playlists.PlaylistsPage
      live "/movies/:tmdb_id", Contents.ContentPage, :movie
      live "/shows/:tmdb_id", Contents.ContentPage, :tv_show
    end

    ash_authentication_live_session :unauthenticated_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_no_user},
        WatchClubWeb.Hooks.Locale,
        WatchClubWeb.Hooks.InstanceSettings
      ] do
      live "/setup", Accounts.SetupPage
      live "/sign-in", Accounts.SignInPage
      # The code is a query parameter, not a path segment, so telemetry redacts it
      live "/join", Invitations.InvitationPage
    end

    ash_authentication_live_session :optional_user_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_user_optional},
        WatchClubWeb.Hooks.Locale,
        WatchClubWeb.Hooks.InstanceSettings
      ] do
      # The reset link works whether the user is logged in or not
      live "/reset-password", Accounts.ResetPasswordPage
    end

    # Auto-generated POST and callbacks routes from Ash Authentication
    auth_routes AuthController, WatchClub.Accounts.User, path: "/auth"
    sign_out_route AuthController, "/sign-out"
  end

  # Other scopes may use custom stacks.
  # scope "/api", WatchClubWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:watch_club, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router
    import Oban.Web.Router

    scope "/" do
      storybook_assets()
    end

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WatchClubWeb.Telemetry
      oban_dashboard("/oban")
      # forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    live_storybook("/dev/storybook", backend_module: WatchClubWeb.Storybook)
  end

  defp ensure_administrator_setup(%Plug.Conn{request_path: "/setup"} = conn, _opts) do
    if WatchClub.Accounts.administrator_exists?() do
      conn |> redirect(to: ~p"/") |> halt()
    else
      conn
    end
  end

  defp ensure_administrator_setup(conn, _opts) do
    if WatchClub.Accounts.administrator_exists?() do
      conn
    else
      conn |> redirect(to: ~p"/setup") |> halt()
    end
  end

  defp require_current_user(%{assigns: %{current_user: %User{}}} = conn, _opts), do: conn

  defp require_current_user(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end

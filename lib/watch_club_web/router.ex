defmodule WatchClubWeb.Router do
  use WatchClubWeb, :router

  use Phoenix.VerifiedRoutes,
    endpoint: WatchClubWeb.Endpoint,
    router: WatchClubWeb.Router,
    statics: WatchClubWeb.static_paths()

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers
  import PhoenixStorybook.Router

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

  # Like :browser but without CSRF protection — HLS segment GETs from
  # <media-player> don't carry a CSRF token. No HTML rendering either,
  # so :accepts, layouts, and flash are intentionally absent.
  pipeline :playback do
    plug :fetch_session
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :ensure_administrator_setup
  end

  scope "/webhooks", WatchClubWeb.Webhooks do
    pipe_through :webhook

    post "/radarr/:media_source_id", RadarrController, :handle
  end

  scope "/hls", WatchClubWeb do
    pipe_through :playback

    get "/:session_id/master.m3u8", PlayerController, :master_playlist
    get "/:session_id/video/:variant/index.m3u8", PlayerController, :video_playlist
    get "/:session_id/audio/:track_id/index.m3u8", PlayerController, :audio_playlist
    get "/:session_id/subtitles/:track_id/index.m3u8", PlayerController, :subtitle_playlist
    get "/:session_id/video/:variant/:segment", PlayerController, :video_segment
    get "/:session_id/audio/:track_id/:segment", PlayerController, :audio_segment
    get "/:session_id/subtitles/:track_id/:file", PlayerController, :subtitle_file
  end

  scope "/", WatchClubWeb do
    pipe_through :browser

    ash_authentication_live_session :administrator_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_administrator_required},
        WatchClubWeb.Hooks.Locale
      ] do
      live "/admin/settings", Admin.InstanceSettingsPage
      live "/admin/media", Admin.MediaBrowserPage
      live "/admin/media/sources", Admin.MediaSourcesPage
      live "/admin/media/sources/:id/history", Admin.MediaSourceHistoryPage
    end

    ash_authentication_live_session :authenticated_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_user_required},
        WatchClubWeb.Hooks.Locale
      ] do
      live "/", HomePage
      live "/play/:media_id", PlayerPage
      live "/search", SearchPage
      live "/settings", Accounts.SettingsPage
      live "/my-requests", MyRequestsPage
      live "/clubs/:club_id", Clubs.ClubPage
      live "/clubs/:club_id/members", Clubs.MembersPage
      live "/clubs/:club_id/settings", Clubs.SettingsPage
      live "/clubs/:club_id/libraries/:library_id", Clubs.LibraryPage
      live "/books/:hardcover_id", Contents.BookDetailsPage
      live "/movies/:tmdb_id", Contents.MovieDetailsPage
      live "/shows/:tmdb_id", Contents.TvShowDetailsPage
    end

    ash_authentication_live_session :unauthenticated_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_no_user},
        WatchClubWeb.Hooks.Locale
      ] do
      live "/setup", Accounts.SetupPage
      live "/sign-in", Accounts.SignInPage
    end

    ash_authentication_live_session :optional_user_routes,
      on_mount: [
        WatchClubWeb.Hooks.CurrentUrl,
        WatchClubWeb.Hooks.Flash,
        {WatchClubWeb.Hooks.Auth, :live_user_optional},
        WatchClubWeb.Hooks.Locale
      ] do
      live "/invitations/:invitation_id", Invitations.InvitationPage
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

    scope "/" do
      storybook_assets()
    end

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WatchClubWeb.Telemetry
      # forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    live_storybook("/dev/storybook", backend_module: WatchClubWeb.Storybook)
  end

  defp ensure_administrator_setup(%Plug.Conn{request_path: "/setup"} = conn, _opts) do
    if WatchClub.Accounts.administrator_exists?() do
      conn |> redirect(to: ~p"/")
    else
      conn
    end
  end

  defp ensure_administrator_setup(conn, _opts) do
    if WatchClub.Accounts.administrator_exists?() do
      conn
    else
      conn |> redirect(to: ~p"/setup")
    end
  end
end

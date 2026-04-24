defmodule WatchClubWeb.Router do
  use WatchClubWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WatchClubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", WatchClubWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes,
      on_mount: {WatchClubWeb.LiveUserAuth, :live_user_required} do
      live "/clubs", ClubLive.Index
      live "/clubs/new", ClubLive.Form
      live "/clubs/:id", ClubLive.Show
      live "/clubs/:id/edit", ClubLive.Form
    end

    get "/", PageController, :home
    auth_routes AuthController, WatchClub.Accounts.User, path: "/auth"

    # Auth routes
    sign_out_route AuthController

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{WatchClubWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    WatchClubWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  WatchClubWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    confirm_route WatchClub.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [WatchClubWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
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

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WatchClubWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

defmodule RainingWeb.Router do
  use RainingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RainingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug :accepts, ["json"]
    plug RainingWeb.UserAuth, :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: RainingWeb.ApiSpec
  end

  scope "/api", RainingWeb do
    pipe_through :api

    post "/users/register", UserRegistrationController, :create
    post "/users/login", UserSessionController, :create
    delete "/users/logout", UserSessionController, :delete

    # Demo endpoints (public, no auth required)
    get "/demo/zones", DemoController, :zones
  end

  scope "/api", OpenApiSpex do
    pipe_through :api
    get "/openapi", Plug.RenderSpec, []
  end

  scope "/api", RainingWeb do
    pipe_through :auth

    get "/me", UserController, :show

    # Droplet endpoints
    post "/droplets", DropletController, :create
    get "/droplets/feed", DropletController, :feed
    get "/droplets/global-feed", DropletController, :global_feed
    get "/droplets/:id", DropletController, :show

    # Weather endpoints
    get "/weather/check", WeatherController, :check
  end

  scope "/" do
    pipe_through :browser

    get "/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:raining, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RainingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

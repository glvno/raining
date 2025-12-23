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
  end

  scope "/api", OpenApiSpex do
    pipe_through :api
    get "/openapi", Plug.RenderSpec, []
  end

  scope "/api", RainingWeb do
    pipe_through :auth

    get "/me", UserController, :show
  end

  scope "/" do
    pipe_through :browser

    get "/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"

    get "/", RainingWeb.PageController, :home
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

  ## Authentication routes

  # scope "/", RainingWeb do
  #   pipe_through [:browser, :redirect_if_user_is_authenticated]
  #
  #   get "/users/register", UserRegistrationController, :new
  #   post "/users/register", UserRegistrationController, :create
  # end
  #
  # scope "/", RainingWeb do
  #   pipe_through [:browser, :require_authenticated_user]
  #
  #   get "/users/settings", UserSettingsController, :edit
  #   put "/users/settings", UserSettingsController, :update
  #   get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  # end
  #
  # scope "/", RainingWeb do
  #   pipe_through [:browser]
  #
  #   get "/users/log-in", UserSessionController, :new
  #   get "/users/log-in/:token", UserSessionController, :confirm
  #   post "/users/log-in", UserSessionController, :create
  #   delete "/users/log-out", UserSessionController, :delete
  # end
end

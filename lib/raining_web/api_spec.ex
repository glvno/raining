defmodule RainingWeb.ApiSpec do
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}
  alias RainingWeb.{Endpoint, Router}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Raining API",
        version: "1.0.0",
        description: """
        Raining is a location-based social app that connects people during rain events.
        Users can post "droplets" (geo-tagged messages) and see posts from others in the same rain area.

        ## Authentication

        Most endpoints require Bearer token authentication. Obtain a token via:
        - `POST /api/users/register` - Create a new account
        - `POST /api/users/login` - Log in with email/password

        Include the token in requests: `Authorization: Bearer <token>`
        """
      },
      # Security scheme definition
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description: "Bearer token obtained from login or registration"
          }
        }
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router)
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end

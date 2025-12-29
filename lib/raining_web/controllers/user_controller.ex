defmodule RainingWeb.UserController do
  use RainingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias RainingWeb.Schemas.User

  tags ["Users"]

  operation :show,
    summary: "Get current user",
    description: "Returns the currently authenticated user's information. Requires Bearer token authentication.",
    responses: [
      ok: {"Current user", "application/json", User},
      unauthorized: {"Not authenticated", "application/json", nil}
    ],
    security: [%{"authorization" => []}]

  def show(conn, _params) do
    user = conn.assigns.current_user

    json(conn, %{
      id: user.id,
      email: user.email
    })
  end
end

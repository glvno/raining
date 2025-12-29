defmodule RainingWeb.UserSessionController do
  use RainingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Raining.Accounts
  alias RainingWeb.Schemas.{LoginParams, AuthResponse, ErrorResponse}

  tags ["Authentication"]

  operation :create,
    summary: "Log in user",
    description: "Authenticates a user with email and password, returning a Bearer token",
    request_body: {"Login credentials", "application/json", LoginParams, required: true},
    responses: [
      ok: {"Login successful", "application/json", AuthResponse},
      unauthorized: {"Invalid credentials", "application/json", ErrorResponse}
    ]

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_credentials"})

      user ->
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_status(:ok)
        |> json(%{
          token: token,
          user: %{
            id: user.id,
            email: user.email
          }
        })
    end
  end

  operation :delete,
    summary: "Log out user",
    description: "Invalidates the current session token. Requires Bearer token authentication.",
    responses: [
      no_content: {"Logged out successfully", "application/json", nil}
    ],
    security: [%{"authorization" => []}]

  def delete(conn, _params) do
    RainingWeb.UserAuth.log_out_user(conn)
    |> send_resp(:no_content, "")
  end
end

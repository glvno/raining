defmodule RainingWeb.UserRegistrationController do
  use RainingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Raining.Accounts
  alias RainingWeb.Schemas.{UserRegistrationParams, AuthResponse, ValidationErrorResponse}

  tags ["Authentication"]

  operation :create,
    summary: "Register user",
    description: """
    Creates a new user account and returns a Bearer token for immediate authentication.
    Password is optional - users can register with just an email for magic-link authentication.
    """,
    request_body: {"User registration params", "application/json", UserRegistrationParams, required: true},
    responses: [
      created: {"Registration successful", "application/json", AuthResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Generate session token so user is automatically logged in
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_status(:created)
        |> json(%{
          token: token,
          user: %{
            id: user.id,
            email: user.email
          }
        })

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end
end

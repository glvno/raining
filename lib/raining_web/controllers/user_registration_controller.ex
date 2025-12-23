defmodule RainingWeb.UserRegistrationController do
  use RainingWeb, :controller
  alias Raining.Accounts
  alias RainingWeb.Schemas.{UserRegistrationParams, UserResponse}

  use OpenApiSpex.ControllerSpecs

  operation :create,
    summary: "Create user",
    parameters: [
      email: [in: :body, description: "User email", type: :string, example: "test@example.com"],
      password: [in: :body, description: "User password", type: :string, example: "password"]
    ],
    request_body: {"User params", "application/json", UserRegistrationParams},
    responses: [
      ok: {"User response", "application/json", UserResponse}
    ]

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{id: user.id, email: user.email})

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

defmodule RainingWeb.UserSessionController do
  use RainingWeb, :controller
  alias Raining.Accounts

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

  def delete(conn, _params) do
    RainingWeb.UserAuth.log_out_user(conn)
    |> send_resp(:no_content, "")
  end
end

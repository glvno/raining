defmodule RainingWeb.UserAuth do
  import Plug.Conn
  alias MyApp.Accounts

  @behaviour Plug

  # Plug behaviour for the :auth pipeline
  @impl Plug
  def init(:fetch_current_scope_for_user), do: :fetch_current_scope_for_user
  def init(opts), do: opts

  @impl Plug
  def call(conn, :fetch_current_scope_for_user), do: fetch_current_scope_for_user(conn)

  # Public API plug function
  def fetch_current_scope_for_user(conn, _opts \\ []) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- verify_api_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> send_resp(:unauthorized, Jason.encode!(%{error: "unauthorized"}))
        |> halt()
    end
  end

  # Use the generated Accounts token logic; adjust names if needed
  defp verify_api_token(token) do
    case Accounts.get_user_by_session_token(token) do
      nil -> {:error, :invalid}
      user -> {:ok, user}
    end
  end
end

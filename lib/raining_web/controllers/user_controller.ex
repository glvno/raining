defmodule RainingWeb.UserController do
  use RainingWeb, :controller

  def show(conn, _params) do
    user = conn.assigns.current_user

    json(conn, %{
      id: user.id,
      email: user.email
    })
  end
end

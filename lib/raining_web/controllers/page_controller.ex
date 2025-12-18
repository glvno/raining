defmodule RainingWeb.PageController do
  use RainingWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

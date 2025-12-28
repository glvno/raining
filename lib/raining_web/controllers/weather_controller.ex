defmodule RainingWeb.WeatherController do
  use RainingWeb, :controller
  alias Raining.Weather

  @doc """
  Checks if it's raining at the given coordinates.

  Returns the rounded coordinates and rain status.
  """
  def check(conn, %{"latitude" => lat_str, "longitude" => lng_str}) do
    with {lat, ""} <- Float.parse(lat_str),
         {lng, ""} <- Float.parse(lng_str) do
      # Round coordinates to match weather grid
      rounded_lat = Weather.round_coordinate(lat)
      rounded_lng = Weather.round_coordinate(lng)

      case Weather.is_raining?(rounded_lat, rounded_lng) do
        {:ok, is_raining} ->
          json(conn, %{
            is_raining: is_raining,
            rounded_latitude: rounded_lat,
            rounded_longitude: rounded_lng,
            original_latitude: lat,
            original_longitude: lng
          })

        {:error, reason} ->
          conn
          |> put_status(:service_unavailable)
          |> json(%{error: "Weather service unavailable", reason: inspect(reason)})
      end
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid latitude or longitude"})
    end
  end
end

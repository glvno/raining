defmodule RainingWeb.DropletController do
  use RainingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Raining.Droplets
  alias Raining.Droplets.Droplet
  alias RainingWeb.Schemas.{DropletParams, DropletResponse, DropletsResponse}

  tags ["Droplets"]

  operation :create,
    summary: "Create a droplet",
    request_body: {"Droplet params", "application/json", DropletParams, required: true},
    responses: [
      created: {"Droplet created", "application/json", DropletResponse},
      unprocessable_entity: {"Validation errors", "application/json", nil},
      bad_request: {"Bad request", "application/json", nil}
    ],
    security: [%{"authorization" => []}]

  @doc """
  Creates a new droplet for the current user.

  Expects JSON body with:
  - content (required): Text content (1-500 characters)
  - latitude (required): Latitude coordinate (-90 to 90)
  - longitude (required): Longitude coordinate (-180 to 180)

  Returns 201 Created with droplet data, or 422 Unprocessable Entity with errors.
  """
  def create(conn, %{"droplet" => droplet_params}) do
    user = conn.assigns.current_user

    case Droplets.create_droplet(Map.put(droplet_params, "user_id", user.id)) do
      {:ok, %Droplet{} = droplet} ->
        droplet_with_user = Raining.Repo.preload(droplet, :user)

        conn
        |> put_status(:created)
        |> json(%{droplet: format_droplet(droplet_with_user)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required 'droplet' parameter"})
  end

  operation :show,
    summary: "Get a droplet by ID",
    parameters: [
      id: [in: :path, description: "Droplet ID", type: :integer, example: 1]
    ],
    responses: [
      ok: {"Droplet found", "application/json", DropletResponse},
      not_found: {"Droplet not found", "application/json", nil},
      bad_request: {"Invalid droplet ID", "application/json", nil}
    ],
    security: [%{"authorization" => []}]

  @doc """
  Shows a single droplet by ID.

  Returns 200 OK with droplet data, or 404 Not Found.
  """
  def show(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {id_int, ""} ->
        try do
          droplet = Droplets.get_droplet!(id_int)

          json(conn, %{droplet: format_droplet(droplet)})
        rescue
          Ecto.NoResultsError ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Droplet not found"})
        end

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid droplet ID"})
    end
  end

  operation :feed,
    summary: "Get local feed of droplets in the same rain area",
    parameters: [
      latitude: [
        in: :query,
        description: "User's current latitude",
        type: :number,
        required: true,
        example: 52.5
      ],
      longitude: [
        in: :query,
        description: "User's current longitude",
        type: :number,
        required: true,
        example: 13.4
      ],
      time_window_hours: [
        in: :query,
        description: "Hours to look back (default: 2)",
        type: :integer,
        required: false,
        example: 2
      ]
    ],
    responses: [
      ok: {"Feed of droplets", "application/json", DropletsResponse},
      bad_request: {"Invalid parameters", "application/json", nil},
      service_unavailable: {"Weather service error", "application/json", nil}
    ],
    security: [%{"authorization" => []}]

  @doc """
  Returns the local feed of droplets in the same rain area.

  Required query parameters:
  - latitude: User's current latitude
  - longitude: User's current longitude

  Optional query parameters:
  - time_window_hours: Hours to look back (default: from config)

  Returns 200 OK with droplets array, 400 Bad Request for invalid params,
  or 503 Service Unavailable for weather API errors.
  """
  def feed(conn, params) do
    with {:ok, lat} <- parse_float(params["latitude"]),
         {:ok, lng} <- parse_float(params["longitude"]) do
      opts = build_feed_opts(params)

      case Droplets.get_local_feed(lat, lng, opts) do
        {:ok, droplets, zone_geometry} ->
          rain_zone = Droplets.zone_to_geojson(zone_geometry)

          json(conn, %{
            droplets: Enum.map(droplets, &format_droplet/1),
            count: length(droplets),
            time_window_hours:
              Keyword.get(opts, :time_window_hours, Droplets.get_time_window_hours()),
            rain_zone: rain_zone
          })

        {:error, :no_rain} ->
          json(conn, %{
            droplets: [],
            count: 0,
            message: "Not raining at your location",
            rain_zone: nil
          })

        {:error, reason} ->
          conn
          |> put_status(:service_unavailable)
          |> json(%{error: "Weather service error: #{inspect(reason)}"})
      end
    else
      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid or missing latitude/longitude parameters"})
    end
  end

  # Private helper functions

  defp parse_float(nil), do: {:error, :missing}

  defp parse_float(value) when is_float(value), do: {:ok, value}

  defp parse_float(value) when is_integer(value), do: {:ok, value / 1}

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, :invalid}
    end
  end

  defp parse_float(_), do: {:error, :invalid}

  defp build_feed_opts(params) do
    case parse_integer(params["time_window_hours"]) do
      {:ok, hours} -> [time_window_hours: hours]
      {:error, _} -> []
    end
  end

  defp parse_integer(nil), do: {:error, :missing}

  defp parse_integer(value) when is_integer(value), do: {:ok, value}

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid}
    end
  end

  defp parse_integer(_), do: {:error, :invalid}

  defp format_droplet(%Droplet{} = droplet) do
    %{
      id: droplet.id,
      content: droplet.content,
      latitude: droplet.latitude,
      longitude: droplet.longitude,
      user: format_user(droplet.user),
      inserted_at: droplet.inserted_at,
      updated_at: droplet.updated_at
    }
  end

  defp format_user(%Raining.Accounts.User{} = user) do
    %{
      id: user.id,
      email: user.email
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

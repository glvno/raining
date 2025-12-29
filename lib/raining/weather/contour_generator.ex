defmodule Raining.Weather.ContourGenerator do
  @moduledoc """
  Generates contour-based precipitation polygons from weather data.
  Uses PostGIS spatial functions to create accurate rain area boundaries.
  """

  alias Raining.Repo
  alias Geo.Point

  @doc """
  Generate rain area polygon from precipitation grid data.

  Takes a grid of precipitation values and user coordinates, returns a polygon
  representing the precipitation area containing the user.

  ## Parameters
    - `precipitation_data`: Map with `:points` (list of {lat, lng, precip_mm}) and `:bounds`
    - `user_lat`: User's latitude
    - `user_lng`: User's longitude
    - `opts`: Options including:
      - `:threshold` - Minimum precipitation in mm (default: 0.1)
      - `:target_percent` - Concave hull target percent (default: 0.85)

  ## Returns
    - `{:ok, polygon}` - Geo.Polygon or Geo.MultiPolygon containing the user
    - `{:error, :no_precipitation}` - No precipitation found in grid
    - `{:error, :user_not_in_rain}` - User not within precipitation area

  ## Examples

      iex> precipitation_data = %{
      ...>   points: [{40.9, -87.1, 2.5}, {40.95, -87.05, 1.8}, ...],
      ...>   bounds: {40.5, 41.5, -87.5, -86.5}
      ...> }
      iex> ContourGenerator.generate_polygon(precipitation_data, 40.94, -87.08)
      {:ok, %Geo.Polygon{...}}
  """
  def generate_polygon(precipitation_data, user_lat, user_lng, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.1)
    target_percent = Keyword.get(opts, :target_percent, 0.85)

    # Filter to points with significant precipitation
    precip_points =
      precipitation_data.points
      |> Enum.filter(fn {_lat, _lng, precip_mm} -> precip_mm >= threshold end)

    if Enum.empty?(precip_points) do
      {:error, :no_precipitation}
    else
      user_point = %Point{coordinates: {user_lng, user_lat}, srid: 4326}

      case generate_concave_hull(precip_points, user_point, target_percent) do
        {:ok, polygon} -> {:ok, polygon}
        {:error, _} = error -> error
      end
    end
  end

  # Generate a concave hull polygon from precipitation points.
  # Uses PostGIS ST_ConcaveHull to create a tight-fitting polygon around
  # precipitation points. This creates a more accurate boundary than convex hull.
  defp generate_concave_hull(precip_points, user_point, target_percent) do
    # Build point array using ST_MakePoint
    points_sql = build_point_array_sql(precip_points)

    # Build user point coordinates
    %Point{coordinates: {user_lng, user_lat}} = user_point

    # Create a multipoint geometry from all precipitation points
    query = """
    WITH points AS (
      SELECT ST_Collect(ARRAY[#{points_sql}]) AS geom
    ),
    hull AS (
      SELECT ST_ConcaveHull(geom, $1) AS geom
      FROM points
    )
    SELECT
      ST_AsEWKB(hull.geom) AS polygon,
      ST_Contains(hull.geom, ST_SetSRID(ST_MakePoint($2, $3), 4326)) AS contains_user
    FROM hull
    """

    case Repo.query(query, [target_percent, user_lng, user_lat]) do
      {:ok, %{rows: [[polygon_wkb, true]]}} ->
        {:ok, Geo.WKB.decode!(polygon_wkb)}

      {:ok, %{rows: [[_polygon_wkb, false]]}} ->
        # Try with a looser hull (lower target_percent) to see if user is on edge
        if target_percent > 0.5 do
          generate_concave_hull(precip_points, user_point, target_percent - 0.15)
        else
          {:error, :user_not_in_rain}
        end

      {:ok, %{rows: []}} ->
        {:error, :no_precipitation}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Build array of ST_MakePoint calls for precipitation points
  defp build_point_array_sql(precip_points) do
    precip_points
    |> Enum.map(fn {lat, lng, _precip_mm} ->
      "ST_SetSRID(ST_MakePoint(#{lng}, #{lat}), 4326)"
    end)
    |> Enum.join(", ")
  end
end

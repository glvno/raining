defmodule Raining.Demo do
  @moduledoc """
  The Demo context.

  Handles historical radar snapshots and demo zone generation for demo mode.
  Stores precipitation grids with timestamps and generates rain area polygons
  on-demand using the ContourGenerator.
  """

  import Ecto.Query, warn: false
  alias Raining.Repo
  alias Raining.Demo.RadarSnapshot
  alias Raining.Weather.ContourGenerator

  @doc """
  Get demo zones for specified regions.

  Loads the latest snapshot for each region and generates GeoJSON polygons
  from the stored precipitation grids.

  ## Options

    - `:regions` - List of region names to fetch (default: all available)

  ## Returns

    - List of zone maps with `:region`, `:snapshot_timestamp`, and `:rain_zone` keys
    - Empty list if no snapshots found

  ## Examples

      iex> Demo.get_demo_zones()
      [
        %{
          region: "Indiana",
          snapshot_timestamp: ~U[2024-12-28 22:35:00Z],
          rain_zone: %{type: "Polygon", coordinates: [...]}
        },
        ...
      ]

      iex> Demo.get_demo_zones(regions: ["Indiana", "Seattle"])
      [%{region: "Indiana", ...}, %{region: "Seattle", ...}]
  """
  def get_demo_zones(opts \\ []) do
    regions = Keyword.get(opts, :regions)

    query =
      if regions do
        from s in RadarSnapshot,
          where: s.region_name in ^regions,
          distinct: s.region_name,
          order_by: [desc: s.snapshot_timestamp]
      else
        from s in RadarSnapshot,
          distinct: s.region_name,
          order_by: [desc: s.snapshot_timestamp]
      end

    query
    |> Repo.all()
    |> Enum.map(&generate_zone_from_snapshot/1)
    |> Enum.filter(& &1)
  end

  @doc """
  Store a radar snapshot in the database.

  ## Parameters

    - `attrs` - Map with required keys: `:region_name`, `:snapshot_timestamp`,
                `:center_lat`, `:center_lng`, `:precipitation_grid`

  ## Returns

    - `{:ok, %RadarSnapshot{}}` on success
    - `{:error, %Ecto.Changeset{}}` on failure

  ## Examples

      iex> store_radar_snapshot(%{
      ...>   region_name: "Indiana",
      ...>   snapshot_timestamp: DateTime.utc_now(),
      ...>   center_lat: 39.644,
      ...>   center_lng: -86.8645,
      ...>   precipitation_grid: %{points: [...]},
      ...>   metadata: %{max_precip_mm: 37.8}
      ...> })
      {:ok, %RadarSnapshot{}}
  """
  def store_radar_snapshot(attrs) do
    %RadarSnapshot{}
    |> RadarSnapshot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get the latest snapshot for a specific region.

  ## Parameters

    - `region_name` - Name of the region (e.g., "Indiana", "Seattle")

  ## Returns

    - `%RadarSnapshot{}` if found
    - `nil` if no snapshot exists for the region

  ## Examples

      iex> get_latest_snapshot("Indiana")
      %RadarSnapshot{region_name: "Indiana", ...}

      iex> get_latest_snapshot("NonExistent")
      nil
  """
  def get_latest_snapshot(region_name) do
    RadarSnapshot
    |> where([s], s.region_name == ^region_name)
    |> order_by([s], desc: s.snapshot_timestamp)
    |> limit(1)
    |> Repo.one()
  end

  # Generate a GeoJSON zone from a radar snapshot.
  #
  # Extracts the precipitation grid from the snapshot and uses ContourGenerator
  # to create a polygon. Returns a map suitable for API responses.
  defp generate_zone_from_snapshot(snapshot) do
    # Extract precipitation grid points
    points =
      case snapshot.precipitation_grid do
        %{"points" => points} when is_list(points) ->
          # Convert from map format to tuple format if needed
          Enum.map(points, fn
            %{"lat" => lat, "lng" => lng, "precip_mm" => precip} ->
              {lat, lng, precip}

            {lat, lng, precip} ->
              {lat, lng, precip}
          end)

        points when is_list(points) ->
          points

        _ ->
          []
      end

    if Enum.empty?(points) do
      nil
    else
      # Prepare precipitation data for ContourGenerator
      precip_data = %{
        points: points,
        bounds: calculate_bounds(points)
      }

      # Generate polygon using ContourGenerator
      case ContourGenerator.generate_polygon(
             precip_data,
             snapshot.center_lat,
             snapshot.center_lng
           ) do
        {:ok, polygon} ->
          # Convert to GeoJSON
          {:ok, geojson} = Geo.JSON.encode(polygon)

          %{
            region: snapshot.region_name,
            snapshot_timestamp: snapshot.snapshot_timestamp,
            rain_zone: geojson,
            metadata: snapshot.metadata
          }

        {:error, _reason} ->
          # If contour generation fails, return nil
          nil
      end
    end
  end

  # Calculate bounding box from precipitation points
  defp calculate_bounds(points) do
    lats = Enum.map(points, &elem(&1, 0))
    lngs = Enum.map(points, &elem(&1, 1))

    {Enum.min(lats), Enum.max(lats), Enum.min(lngs), Enum.max(lngs)}
  end
end

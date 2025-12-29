defmodule Raining.Droplets do
  @moduledoc """
  The Droplets context.

  Handles creation and querying of droplets (social posts with geolocation).
  Provides a local feed feature that shows only droplets from the same
  contiguous rain area within a configurable time window.
  """

  import Ecto.Query, warn: false
  alias Raining.Repo
  alias Raining.Droplets.Droplet
  alias Raining.Droplets.RainStatusCache
  alias Raining.Weather

  @doc """
  Creates a droplet.

  ## Examples

      iex> create_droplet(%{content: "Hello", latitude: 52.5, longitude: 13.4, user_id: 1})
      {:ok, %Droplet{}}

      iex> create_droplet(%{content: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_droplet(attrs \\ %{}) do
    %Droplet{}
    |> Droplet.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single droplet with user preloaded.

  Raises `Ecto.NoResultsError` if the Droplet does not exist.

  ## Examples

      iex> get_droplet!(123)
      %Droplet{id: 123, user: %User{}}

      iex> get_droplet!(456)
      ** (Ecto.NoResultsError)

  """
  def get_droplet!(id) do
    Droplet
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  @doc """
  Returns all droplets for a given user, sorted by most recent first.

  ## Examples

      iex> list_user_droplets(user_id)
      [%Droplet{}, ...]

  """
  def list_user_droplets(user_id) do
    Droplet
    |> where([d], d.user_id == ^user_id)
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Returns droplets from the same contiguous rain area within a time window.

  This function implements the core feed algorithm:
  1. Queries droplets created within the time window (using indexed query)
  2. Calls Weather.find_rain_area/2 to get the contiguous rain area
  3. Filters droplets by rounding their coordinates and matching against rain area
  4. Returns droplets sorted by most recent first with users preloaded

  ## Parameters

    - `latitude`: User's current latitude
    - `longitude`: User's current longitude
    - `opts`: Keyword list of options
      - `:time_window_hours` - Hours to look back (default: from config)

  ## Returns

    - `{:ok, [%Droplet{}]}` - List of droplets in the rain area (may be empty)
    - `{:error, reason}` - Weather API error

  ## Examples

      iex> get_local_feed(52.5, 13.4)
      {:ok, [%Droplet{}, ...]}

      iex> get_local_feed(0.0, 0.0)  # Not raining
      {:ok, []}

      iex> get_local_feed(999, 999)  # Invalid coordinates
      {:error, reason}

  """
  def get_local_feed(latitude, longitude, opts \\ []) do
    time_window_hours = Keyword.get(opts, :time_window_hours, get_time_window_hours())

    # Check if user's location is in any cached raining zone (NWS zones or old coordinate-based)
    case check_zone_cache(latitude, longitude) do
      {:ok, zone_geometry} ->
        # Cache hit! Use cached zone polygon to filter droplets
        require Logger
        Logger.info("✅ Zone Cache HIT: Using cached zone geometry - NO API CALL")
        get_droplets_in_zone(zone_geometry, time_window_hours)

      {:error, :cache_miss} ->
        # Cache miss - use radar-based polygon generation
        require Logger
        Logger.info("❌ Zone Cache MISS: Querying weather APIs")
        get_feed_with_radar_check(latitude, longitude, time_window_hours)
    end
  end

  @doc """
  Returns all non-expired droplets globally in chronological order
  along with all active rain zones for map visualization.

  This function provides the global feed with:
  - All droplets within the time window (no spatial filtering)
  - All active rain zones from the cache for map display

  ## Parameters

    - `opts`: Keyword list of options
      - `:time_window_hours` - Hours to look back (default: from config)

  ## Returns

    - `{:ok, droplets, rain_zones}` - List of droplets and list of rain zone polygons

  ## Examples

      iex> get_global_feed()
      {:ok, [%Droplet{}, ...], [%{polygon: %Geo.Polygon{}}, ...]}

      iex> get_global_feed(time_window_hours: 1)
      {:ok, [%Droplet{}, ...], [%{polygon: %Geo.Polygon{}}, ...]}

  """
  def get_global_feed(opts \\ []) do
    time_window_hours = Keyword.get(opts, :time_window_hours, get_time_window_hours())
    cutoff_time = DateTime.utc_now() |> DateTime.add(-time_window_hours, :hour)

    # Get all non-expired droplets
    droplets =
      Droplet
      |> where([d], d.inserted_at >= ^cutoff_time)
      |> order_by([d], desc: d.inserted_at)
      |> Repo.all()
      |> Repo.preload(:user)

    # Get all active rain zones from cache
    rain_zones =
      RainStatusCache
      |> where([r], r.is_raining == true and r.expires_at > ^DateTime.utc_now())
      |> select([r], %{polygon: r.geometry})
      |> Repo.all()

    {:ok, droplets, rain_zones}
  end

  @doc """
  Converts zone geometry to GeoJSON format for API responses.

  Handles two cases:
  1. PostGIS Geometry (from NWS zones) - converts to GeoJSON
  2. Coordinate list (from Open-Meteo) - converts to bounding box polygon

  Returns nil if geometry cannot be converted.

  ## Examples

      iex> zone_to_geojson(nil)
      nil

      iex> zone_to_geojson(%Geo.Polygon{})
      %{"type" => "Polygon", "coordinates" => [...]}

  """
  def zone_to_geojson(nil), do: nil

  def zone_to_geojson(%Geo.Polygon{} = polygon) do
    # NWS zone geometry - convert PostGIS to GeoJSON
    case Geo.JSON.encode(polygon) do
      {:ok, geojson} -> geojson
      {:error, _} -> nil
    end
  end

  def zone_to_geojson(%Geo.MultiPolygon{} = multi_polygon) do
    # Handle MultiPolygon (some NWS zones use this)
    case Geo.JSON.encode(multi_polygon) do
      {:ok, geojson} -> geojson
      {:error, _} -> nil
    end
  end

  def zone_to_geojson(rain_coords) when is_list(rain_coords) and length(rain_coords) > 0 do
    # Open-Meteo coordinate grid - convert to bounding box polygon
    lats = Enum.map(rain_coords, fn {lat, _lng} -> lat end)
    lngs = Enum.map(rain_coords, fn {_lat, lng} -> lng end)

    min_lat = Enum.min(lats)
    max_lat = Enum.max(lats)
    min_lng = Enum.min(lngs)
    max_lng = Enum.max(lngs)

    # Create GeoJSON polygon (lng, lat order per GeoJSON spec)
    %{
      "type" => "Polygon",
      "coordinates" => [
        [
          [min_lng, min_lat],
          [max_lng, min_lat],
          [max_lng, max_lat],
          [min_lng, max_lat],
          # Close the ring
          [min_lng, min_lat]
        ]
      ]
    }
  end

  def zone_to_geojson(_), do: nil

  defp get_feed_with_radar_check(latitude, longitude, time_window_hours) do
    # Calculate search bounding box (2 degree radius ~ 220km)
    bounds = calculate_search_bounds(latitude, longitude, radius: 1.0)

    # Fetch current RainViewer radar timestamp
    case fetch_radar_timestamp() do
      {:ok, timestamp} ->
        # Sample precipitation grid from RainViewer tiles (ensures perfect alignment)
        case Weather.RadarTileSampler.sample_precipitation_grid(
               elem(bounds, 0),
               elem(bounds, 1),
               elem(bounds, 2),
               elem(bounds, 3),
               grid_step: 0.1,
               zoom: 9,
               timestamp: timestamp
             ) do
          {:ok, precip_data} ->
            # Generate contour polygon from precipitation data
            case Weather.ContourGenerator.generate_polygon(precip_data, latitude, longitude) do
              {:ok, polygon} ->
                # Cache the radar-based zone
                cache_raining_zone_radar(polygon, bounds)
                get_droplets_in_zone(polygon, time_window_hours)

              {:error, :user_not_in_rain} ->
                {:error, :no_rain}

              {:error, reason} ->
                {:error, reason}
            end

          {:error, :no_precipitation} ->
            {:error, :no_rain}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        require Logger
        Logger.error("Failed to fetch radar timestamp: #{inspect(reason)}")
        {:error, :radar_unavailable}
    end
  end

  # Fetch current RainViewer radar timestamp
  defp fetch_radar_timestamp do
    url = "https://api.rainviewer.com/public/weather-maps.json"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case get_in(body, ["radar", "past"]) do
          past when is_list(past) and length(past) > 0 ->
            latest = List.last(past)
            timestamp = Map.get(latest, "time")
            {:ok, timestamp}

          _ ->
            require Logger
            Logger.error("Invalid radar data structure in response")
            {:error, :invalid_radar_data}
        end

      {:ok, %{status: status, body: body}} ->
        require Logger
        Logger.error("RainViewer API error - Status: #{status}, Body: #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        require Logger
        Logger.error("Network error fetching radar timestamp: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_search_bounds(lat, lng, opts) do
    radius = Keyword.get(opts, :radius, 2.0)
    {lat - radius, lat + radius, lng - radius, lng + radius}
  end

  defp cache_raining_zone_radar(polygon, {min_lat, max_lat, min_lng, max_lng}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    # Reduce cache expiration to 15 minutes (matches radar update frequency)
    expires_at = DateTime.add(now, 15, :minute)

    # Ensure polygon has SRID 4326
    polygon_with_srid = %{polygon | srid: 4326}

    # Generate zone_id from bounds and timestamp
    unix_timestamp = DateTime.to_unix(now)

    zone_id =
      "radar_#{Float.round(min_lat, 1)}-#{Float.round(max_lat, 1)}_#{Float.round(min_lng, 1)}-#{Float.round(max_lng, 1)}_#{unix_timestamp}"

    zone_name =
      "Radar Precipitation Area (#{Float.round(min_lat, 1)}°, #{Float.round(min_lng, 1)}°)"

    attrs = %{
      zone_id: zone_id,
      zone_name: zone_name,
      geometry: polygon_with_srid,
      is_raining: true,
      last_checked: now,
      expires_at: expires_at
    }

    %RainStatusCache{}
    |> RainStatusCache.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :zone_id)

    require Logger
    Logger.info("Cached radar zone: #{zone_id} (expires in 15 minutes)")
  end

  defp check_zone_cache(latitude, longitude) do
    # Create point for user's location
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    # Find any non-expired cache entry where the point is inside the geometry
    # Use ST_SetSRID to ensure geometry has correct SRID for comparison
    query =
      from c in RainStatusCache,
        where: c.is_raining == true and c.expires_at > ^DateTime.utc_now(),
        where: fragment("ST_Contains(ST_SetSRID(?, 4326), ?)", c.geometry, ^point),
        limit: 1

    case Repo.one(query) do
      nil ->
        {:error, :cache_miss}

      cache_entry ->
        # Ensure returned geometry has SRID set
        geometry =
          if cache_entry.geometry.srid == nil or cache_entry.geometry.srid == 0 do
            %{cache_entry.geometry | srid: 4326}
          else
            cache_entry.geometry
          end

        {:ok, geometry}
    end
  end

  defp get_droplets_in_zone(zone_geometry, time_window_hours) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-time_window_hours, :hour)

    # Ensure zone_geometry has SRID 4326
    zone_geom =
      if zone_geometry.srid == nil or zone_geometry.srid == 0 do
        %{zone_geometry | srid: 4326}
      else
        zone_geometry
      end

    # Get all droplets in time window that fall within the zone geometry
    # Use ST_MakePoint with SRID 4326 to ensure consistent coordinate system
    query =
      from d in Droplet,
        where: d.inserted_at >= ^cutoff_time,
        where:
          fragment(
            "ST_Contains(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
            ^zone_geom,
            d.longitude,
            d.latitude
          ),
        order_by: [desc: d.inserted_at]

    droplets = Repo.all(query) |> Repo.preload(:user)
    {:ok, droplets, zone_geom}
  end

  @doc """
  Checks if a droplet is within the given rain area coordinates.

  Rounds the droplet's unrounded coordinates to match the weather grid
  precision, then checks if the rounded coordinate exists in the rain area.

  ## Examples

      iex> droplet = %Droplet{latitude: 52.527, longitude: 13.416}
      iex> rain_coords = [{52.5, 13.4}, {52.6, 13.4}]
      iex> droplet_in_rain_area?(droplet, rain_coords)
      true

      iex> droplet = %Droplet{latitude: 40.7, longitude: -74.0}
      iex> rain_coords = [{52.5, 13.4}]
      iex> droplet_in_rain_area?(droplet, rain_coords)
      false

  """
  def droplet_in_rain_area?(%Droplet{latitude: lat, longitude: lng}, rain_coords) do
    # Round droplet coordinates to match weather grid precision
    rounded_lat = Weather.round_coordinate(lat)
    rounded_lng = Weather.round_coordinate(lng)
    rounded_droplet_coord = {rounded_lat, rounded_lng}

    # Check if rounded coordinate exists in rain area
    Enum.member?(rain_coords, rounded_droplet_coord)
  end

  @doc """
  Returns the configured time window in hours for the local feed.

  Defaults to 2 hours if not configured.

  ## Examples

      iex> get_time_window_hours()
      2

  """
  def get_time_window_hours do
    Application.get_env(:raining, :droplets_time_window_hours, 2)
  end
end

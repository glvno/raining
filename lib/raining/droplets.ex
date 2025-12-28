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

    # Check cache first
    case check_rain_status_cache(latitude, longitude) do
      {:ok, false, _rain_coords} ->
        # Cache says no rain
        require Logger
        Logger.info("Cache HIT: No rain at #{latitude}, #{longitude}")
        {:error, :no_rain}

      {:ok, true, rain_coords} ->
        # Cache says it's raining, use cached rain coords
        require Logger
        Logger.info("Cache HIT: Rain detected at #{latitude}, #{longitude} (#{length(rain_coords)} coords)")
        get_droplets_in_rain_area(rain_coords, time_window_hours)

      {:error, :cache_miss} ->
        # No cache entry, check weather API
        require Logger
        Logger.info("Cache MISS: Calling weather API for #{latitude}, #{longitude}")
        get_feed_with_weather_check(latitude, longitude, time_window_hours)
    end
  end

  defp get_feed_with_weather_check(latitude, longitude, time_window_hours) do
    case Weather.find_rain_area(latitude, longitude) do
      {:ok, rain_coords} when is_list(rain_coords) ->
        # Cache the positive result with rain coords
        cache_rain_status(latitude, longitude, true, rain_coords)

        get_droplets_in_rain_area(rain_coords, time_window_hours)

      {:error, :no_rain} ->
        # Return error so controller knows it's not raining
        {:error, :no_rain}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_droplets_in_rain_area(rain_coords, time_window_hours) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-time_window_hours, :hour)

    droplets_in_time_window =
      Droplet
      |> where([d], d.inserted_at >= ^cutoff_time)
      |> Repo.all()

    droplets_in_rain_area =
      droplets_in_time_window
      |> Enum.filter(fn droplet ->
        droplet_in_rain_area?(droplet, rain_coords)
      end)
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    droplets_with_users = Repo.preload(droplets_in_rain_area, :user)
    {:ok, droplets_with_users}
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

  @doc """
  Checks the rain status cache for the given coordinates.

  Returns {:ok, is_raining, rain_coords} if cache entry exists,
  {:error, :cache_miss} if no valid cache entry exists.
  """
  def check_rain_status_cache(latitude, longitude) do
    case RainStatusCache.get_valid_cache_query(latitude, longitude) |> Repo.one() do
      nil ->
        {:error, :cache_miss}

      cache_entry ->
        # Convert stored map back to list of tuples
        rain_coords = decode_rain_coords(cache_entry.rain_coords)
        {:ok, cache_entry.is_raining, rain_coords}
    end
  end

  @doc """
  Caches the rain status for the given coordinates.

  Cache expires after 1 hour.
  """
  def cache_rain_status(latitude, longitude, is_raining, rain_coords \\ []) do
    expires_at = DateTime.utc_now() |> DateTime.add(1, :hour)

    # Encode rain coords as map for JSON storage
    rain_coords_map = encode_rain_coords(rain_coords)

    attrs = %{
      latitude: latitude,
      longitude: longitude,
      is_raining: is_raining,
      rain_coords: rain_coords_map,
      expires_at: expires_at
    }

    %RainStatusCache{}
    |> RainStatusCache.changeset(attrs)
    |> Repo.insert()
  end

  # Convert list of tuples [{lat, lng}, ...] to JSON-serializable map
  defp encode_rain_coords(rain_coords) when is_list(rain_coords) do
    %{"coords" => Enum.map(rain_coords, fn {lat, lng} -> [lat, lng] end)}
  end

  defp encode_rain_coords(_), do: %{"coords" => []}

  # Convert stored map back to list of tuples
  defp decode_rain_coords(%{"coords" => coords_list}) when is_list(coords_list) do
    Enum.map(coords_list, fn [lat, lng] -> {lat, lng} end)
  end

  defp decode_rain_coords(_), do: []

  @doc """
  Cleans up expired rain status cache entries.

  This can be called periodically to keep the cache table clean.
  """
  def cleanup_expired_cache do
    RainStatusCache.expired_entries_query()
    |> Repo.delete_all()
  end
end

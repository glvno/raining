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

    case Weather.find_rain_area(latitude, longitude) do
      {:ok, rain_coords} when is_list(rain_coords) ->
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

      {:error, :no_rain} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
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

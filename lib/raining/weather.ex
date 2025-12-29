defmodule Raining.Weather do
  @moduledoc """
  Provides weather information using the Open-Meteo API.

  This module supports:
  - Point-in-time rain detection via `is_raining?/2`
  - Contiguous rain area discovery via `find_rain_area/2` using BFS
  """

  @base_url "https://api.open-meteo.com/v1/forecast"
  @grid_step 1.0
  # Calculate precision (decimal places) from grid step
  # 0.1 -> 1, 0.01 -> 2, 0.001 -> 3, etc.
  @precision round(-:math.log10(@grid_step))

  @doc """
  Returns the number of decimal places used for coordinate rounding.

  This value is derived from the grid step resolution.

  ## Examples

      iex> Raining.Weather.precision()
      0

  """
  @spec precision() :: non_neg_integer()
  def precision, do: @precision

  @doc """
  Checks if it is currently raining at the given latitude and longitude coordinates.

  Coordinates are rounded to 1 decimal place before making the API request.

  Returns `{:ok, true}` if it is raining, `{:ok, false}` if it is not raining,
  or `{:error, reason}` if the API request fails.

  ## Examples

      iex> Raining.Weather.is_raining?(52.5, 13.4)
      {:ok, false}

      iex> Raining.Weather.is_raining?(52.527, 13.46)
      {:ok, false}

  """
  @spec is_raining?(number(), number()) :: {:ok, boolean()} | {:error, term()}
  def is_raining?(latitude, longitude) do
    rounded_lat = round_coordinate(latitude)
    rounded_lon = round_coordinate(longitude)

    params = [
      latitude: rounded_lat,
      longitude: rounded_lon,
      current: "rain,precipitation"
    ]

    case Req.get(@base_url, params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, check_if_raining(body)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Rounds a coordinate to the configured precision.

  The number of decimal places is determined by the grid step resolution.
  Use `precision/0` to get the current precision value.

  ## Examples

      iex> Raining.Weather.round_coordinate(52.527)
      53.0

      iex> Raining.Weather.round_coordinate(13.46)
      13.0

  """
  @spec round_coordinate(number()) :: float()
  def round_coordinate(coordinate) do
    Float.round(coordinate / 1, @precision)
  end

  @doc """
  Fetches precipitation grid for a bounding box.

  Returns structured data for contour generation containing precipitation values
  at grid points within the specified bounds.

  ## Parameters

    - `min_lat`: Minimum latitude of bounding box
    - `max_lat`: Maximum latitude of bounding box
    - `min_lng`: Minimum longitude of bounding box
    - `max_lng`: Maximum longitude of bounding box
    - `opts`: Options including:
      - `:grid_step` - Grid resolution in degrees (default: 0.5)
      - `:threshold` - Minimum precipitation in mm to include (default: 0.1)

  ## Returns

    - `{:ok, %{points: [...], bounds: {...}}}` - Precipitation grid data
    - `{:error, :no_precipitation}` - No precipitation found in area
    - `{:error, reason}` - API error

  ## Examples

      # Example result structure when precipitation is found:
      # {:ok, %{
      #   points: [{40.9, -87.1, 2.5}, {40.95, -87.05, 1.8}, ...],
      #   bounds: {40.5, 41.5, -87.5, -86.5}
      # }}

  """
  @spec get_precipitation_grid(number(), number(), number(), number(), keyword()) ::
          {:ok, %{points: [{float(), float(), float()}], bounds: {float(), float(), float(), float()}}}
          | {:error, :no_precipitation | term()}
  def get_precipitation_grid(min_lat, max_lat, min_lng, max_lng, opts \\ []) do
    grid_step = Keyword.get(opts, :grid_step, 0.5)
    threshold = Keyword.get(opts, :threshold, 0.1)

    # Generate grid points within bounding box
    grid_points = generate_grid_points(min_lat, max_lat, min_lng, max_lng, grid_step)

    if Enum.empty?(grid_points) do
      {:error, :no_precipitation}
    else
      # Fetch precipitation data for all grid points in batch
      case fetch_precipitation_batch(grid_points) do
        {:ok, precip_data} ->
          # Filter to points with precipitation above threshold
          filtered_points =
            precip_data
            |> Enum.filter(fn {_lat, _lng, precip} -> precip >= threshold end)

          if Enum.empty?(filtered_points) do
            {:error, :no_precipitation}
          else
            {:ok,
             %{
               points: filtered_points,
               bounds: {min_lat, max_lat, min_lng, max_lng}
             }}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Finds all contiguous coordinates where it's currently raining, starting from the given coordinates.

  Uses Breadth-First Search (BFS) with 8-way connectivity to explore the coordinate grid
  at 0.1-degree resolution. Makes sequential API requests for each layer of the search.

  Coordinates are rounded to 1 decimal place (0.1-degree grid resolution).

  Returns `{:ok, coordinates}` with a list of all coordinates in the rain area,
  `{:error, :no_rain}` if not raining at the starting point, or `{:error, reason}`
  if the initial API request fails.

  ## Parameters

    - `latitude`: The starting latitude coordinate
    - `longitude`: The starting longitude coordinate

  ## Returns

    - `{:ok, [coordinates]}` - List of all `{lat, lng}` tuples in the contiguous rain area
    - `{:error, :no_rain}` - When not raining at starting coordinates
    - `{:error, reason}` - For API errors at the starting coordinate

  ## Examples

      # When not raining at starting point
      iex> case Raining.Weather.find_rain_area(0.0, 0.0) do
      ...>   {:ok, coords} when is_list(coords) -> :rain_detected
      ...>   {:error, :no_rain} -> :no_rain
      ...>   {:error, _} -> :api_error
      ...> end
      :no_rain

      # Finding rain area (example result structure when raining)
      # {:ok, [{52.5, 13.4}, {52.6, 13.4}, {52.5, 13.5}, ...]}

  ## Performance Considerations

  Large storm systems may trigger hundreds or thousands of API calls. The function
  continues until it finds a layer with no rain, which could take significant time
  for large weather systems.

  """
  @spec find_rain_area(number(), number()) ::
          {:ok, [{float(), float()}]} | {:error, :no_rain | term()}
  def find_rain_area(latitude, longitude) do
    starting_coord = round_coordinate_tuple({latitude, longitude})

    # Check if it's raining at starting point
    case is_raining?(latitude, longitude) do
      {:ok, false} ->
        {:error, :no_rain}

      {:ok, true} ->
        # Initialize BFS data structures
        visited = MapSet.new([starting_coord])
        rain_area = [starting_coord]

        # Log starting point
        IO.puts("Starting BFS search from coordinate:")
        IO.inspect(starting_coord)

        # Start BFS expansion
        result = bfs_expand([starting_coord], visited, rain_area)

        # Log completion
        IO.puts("BFS search complete. Total rain area: #{length(result)} coordinate(s)")

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Checks if it's raining based on the API response
  defp check_if_raining(%{"current" => current}) do
    rain = Map.get(current, "rain", 0)
    precipitation = Map.get(current, "precipitation", 0)

    rain > 0 or precipitation > 0
  end

  defp check_if_raining(_), do: false

  # Performs BFS expansion layer by layer
  @spec bfs_expand([{float(), float()}], MapSet.t({float(), float()}), [{float(), float()}]) ::
          [{float(), float()}]
  defp bfs_expand([], _visited, rain_area) do
    # Base case: no more coordinates to explore
    rain_area
  end

  defp bfs_expand(current_layer, visited, rain_area) do
    # Generate all neighbors for current layer
    all_neighbors =
      current_layer
      |> Enum.flat_map(&get_neighbors/1)
      |> Enum.uniq()

    # Filter out already visited coordinates
    new_coordinates =
      all_neighbors
      |> Enum.reject(&MapSet.member?(visited, &1))

    # Early exit if no new coordinates
    if Enum.empty?(new_coordinates) do
      rain_area
    else
      # Check which new coordinates have rain (sequential)
      rain_status = check_multiple_coordinates(new_coordinates)

      # Filter to only raining coordinates
      raining_coords =
        new_coordinates
        |> Enum.filter(fn coord -> Map.get(rain_status, coord, false) end)

      # Log coordinates being added to rain area
      if not Enum.empty?(raining_coords) do
        IO.puts("Adding #{length(raining_coords)} coordinate(s) to rain area:")
        IO.inspect(raining_coords)
      end

      # Update visited set with all new coordinates (not just raining ones)
      new_visited =
        new_coordinates
        |> Enum.reduce(visited, &MapSet.put(&2, &1))

      new_rain_area = rain_area ++ raining_coords

      # Recurse with next layer (only raining coordinates)
      bfs_expand(raining_coords, new_visited, new_rain_area)
    end
  end

  # Generates 8 neighboring coordinates at 0.1 degree offsets
  @spec get_neighbors({float(), float()}) :: [{float(), float()}]
  defp get_neighbors({lat, lng}) do
    # 8-way connectivity: N, S, E, W, NE, NW, SE, SW
    offsets = [
      {0, @grid_step},
      # North
      {0, -@grid_step},
      # South
      {@grid_step, 0},
      # East
      {-@grid_step, 0},
      # West
      {@grid_step, @grid_step},
      # Northeast
      {@grid_step, -@grid_step},
      # Southeast
      {-@grid_step, @grid_step},
      # Northwest
      {-@grid_step, -@grid_step}
      # Southwest
    ]

    offsets
    |> Enum.map(fn {dlat, dlng} ->
      round_coordinate_tuple({lat + dlat, lng + dlng})
    end)
    |> Enum.filter(fn {neighbor_lat, _} ->
      neighbor_lat >= -90.0 and neighbor_lat <= 90.0
    end)
  end

  # Checks multiple coordinates sequentially for rain
  @spec check_multiple_coordinates([{float(), float()}]) :: %{
          {float(), float()} => boolean()
        }
  defp check_multiple_coordinates([]), do: %{}

  defp check_multiple_coordinates(coordinates) do
    coordinates
    |> Enum.reduce(%{}, fn {lat, lng}, acc ->
      case is_raining?(lat, lng) do
        {:ok, is_raining} -> Map.put(acc, {lat, lng}, is_raining)
        {:error, _} -> Map.put(acc, {lat, lng}, false)
      end
    end)
  end

  # Rounds a coordinate tuple to 1 decimal place
  @spec round_coordinate_tuple({number(), number()}) :: {float(), float()}
  defp round_coordinate_tuple({lat, lng}) do
    {round_coordinate(lat), round_coordinate(lng)}
  end

  # Generates grid points within a bounding box
  @spec generate_grid_points(number(), number(), number(), number(), float()) ::
          [{float(), float()}]
  defp generate_grid_points(min_lat, max_lat, min_lng, max_lng, grid_step) do
    # Generate latitude points
    lat_points =
      min_lat
      |> Stream.iterate(&(&1 + grid_step))
      |> Enum.take_while(&(&1 <= max_lat))

    # Generate longitude points
    lng_points =
      min_lng
      |> Stream.iterate(&(&1 + grid_step))
      |> Enum.take_while(&(&1 <= max_lng))

    # Create all combinations
    for lat <- lat_points, lng <- lng_points, do: {lat, lng}
  end

  # Fetches precipitation data for multiple points in a single API request
  @spec fetch_precipitation_batch([{float(), float()}]) ::
          {:ok, [{float(), float(), float()}]} | {:error, term()}
  defp fetch_precipitation_batch([]), do: {:ok, []}

  defp fetch_precipitation_batch(grid_points) do
    # Open-Meteo supports multiple lat/lng values separated by commas
    latitudes = grid_points |> Enum.map(&elem(&1, 0)) |> Enum.join(",")
    longitudes = grid_points |> Enum.map(&elem(&1, 1)) |> Enum.join(",")

    params = [
      latitude: latitudes,
      longitude: longitudes,
      current: "rain,precipitation"
    ]

    case Req.get(@base_url, params: params) do
      {:ok, %{status: 200, body: body}} ->
        parse_batch_precipitation(body, grid_points)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Parses batch precipitation response
  # Open-Meteo returns an array of objects when given multiple coordinates
  @spec parse_batch_precipitation(map() | list(), [{float(), float()}]) ::
          {:ok, [{float(), float(), float()}]} | {:error, term()}
  defp parse_batch_precipitation(body, grid_points) when is_list(body) do
    # Multiple locations - array of response objects
    result =
      body
      |> Enum.zip(grid_points)
      |> Enum.map(fn {location_data, {lat, lng}} ->
        rain = get_in(location_data, ["current", "rain"]) || 0
        precip = get_in(location_data, ["current", "precipitation"]) || 0
        total_precip = rain + precip
        {lat, lng, total_precip}
      end)

    {:ok, result}
  end

  defp parse_batch_precipitation(%{"current" => current}, [{lat, lng}]) do
    # Single location - object with current weather
    rain = Map.get(current, "rain", 0) || 0
    precip = Map.get(current, "precipitation", 0) || 0
    total_precip = rain + precip

    {:ok, [{lat, lng, total_precip}]}
  end

  defp parse_batch_precipitation(_body, _grid_points) do
    {:error, :invalid_response}
  end
end

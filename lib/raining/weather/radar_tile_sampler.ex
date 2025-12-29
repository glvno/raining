defmodule Raining.Weather.RadarTileSampler do
  @moduledoc """
  Samples RainViewer radar tiles to extract precipitation data at specific coordinates.

  This module converts lat/lng coordinates to tile positions, downloads radar tiles,
  and samples pixel colors to determine precipitation intensity. This ensures perfect
  alignment with the radar overlay displayed in the frontend.
  """

  require Logger

  @tile_size 256
  # Universal Blue (will be only option after Jan 2026)
  @color_scheme 2
  @smooth 1
  @snow 1

  @doc """
  Fetches precipitation data by sampling RainViewer radar tiles at grid points.

  ## Parameters
    - `min_lat`: Minimum latitude of bounding box
    - `max_lat`: Maximum latitude of bounding box
    - `min_lng`: Minimum longitude of bounding box
    - `max_lng`: Maximum longitude of bounding box
    - `opts`: Options including:
      - `:grid_step` - Grid resolution in degrees (default: 0.2)
      - `:zoom` - Tile zoom level (default: 6, range: 0-12)
      - `:timestamp` - Unix timestamp for radar frame (required)

  ## Returns
    - `{:ok, %{points: [...], bounds: {...}}}` - Precipitation grid data
    - `{:error, reason}` - Error

  ## Examples
      iex> RadarTileSampler.sample_precipitation_grid(40.0, 41.0, -87.0, -86.0,
      ...>   timestamp: 1234567890, grid_step: 0.2)
      {:ok, %{points: [{40.2, -86.8, 15.5}, ...], bounds: {...}}}
  """
  def sample_precipitation_grid(min_lat, max_lat, min_lng, max_lng, opts \\ []) do
    grid_step = Keyword.get(opts, :grid_step, 0.2)
    zoom = Keyword.get(opts, :zoom, 6)
    timestamp = Keyword.fetch!(opts, :timestamp)

    # Generate grid points to sample
    grid_points = generate_grid_points(min_lat, max_lat, min_lng, max_lng, grid_step)

    if Enum.empty?(grid_points) do
      {:error, :no_grid_points}
    else
      # Group points by tile to minimize downloads
      points_by_tile = group_points_by_tile(grid_points, zoom)

      # Sample each tile and collect results
      sampled_points =
        points_by_tile
        |> Enum.flat_map(fn {{tile_x, tile_y}, points} ->
          case sample_tile(tile_x, tile_y, zoom, timestamp, points) do
            {:ok, results} -> results
            {:error, _reason} -> []
          end
        end)
        # Filter out no/minimal precipitation points
        |> Enum.filter(fn {_lat, _lng, precip_mm} -> precip_mm > 0.1 end)

      if Enum.empty?(sampled_points) do
        {:error, :no_precipitation}
      else
        {:ok,
         %{
           points: sampled_points,
           bounds: {min_lat, max_lat, min_lng, max_lng}
         }}
      end
    end
  end

  # Generate grid points within bounding box
  defp generate_grid_points(min_lat, max_lat, min_lng, max_lng, grid_step) do
    lat_points =
      min_lat
      |> Stream.iterate(&(&1 + grid_step))
      |> Enum.take_while(&(&1 <= max_lat))

    lng_points =
      min_lng
      |> Stream.iterate(&(&1 + grid_step))
      |> Enum.take_while(&(&1 <= max_lng))

    for lat <- lat_points, lng <- lng_points, do: {lat, lng}
  end

  # Group grid points by which tile they fall into
  defp group_points_by_tile(grid_points, zoom) do
    grid_points
    |> Enum.group_by(fn {lat, lng} ->
      {tile_x, tile_y, _pixel_x, _pixel_y} = lat_lng_to_tile_coords(lat, lng, zoom)
      {tile_x, tile_y}
    end)
  end

  # Sample a single tile at multiple coordinates
  defp sample_tile(tile_x, tile_y, zoom, timestamp, points) do
    # Build tile URL
    tile_url = build_tile_url(tile_x, tile_y, zoom, timestamp)

    Logger.debug(
      "Sampling tile #{tile_x},#{tile_y} at zoom #{zoom} with #{length(points)} points"
    )

    # Download and decode tile
    case download_and_decode_tile(tile_url) do
      {:ok, image_data} ->
        # Sample each point from the image
        results =
          points
          |> Enum.map(fn {lat, lng} ->
            {^tile_x, ^tile_y, pixel_x, pixel_y} = lat_lng_to_tile_coords(lat, lng, zoom)
            color = get_pixel_color(image_data, pixel_x, pixel_y)
            dbz = color_to_dbz(color)
            # Convert dBZ to mm/hr for compatibility with existing contour generator
            precip_mm = dbz_to_mm_per_hour(dbz)
            {lat, lng, precip_mm}
          end)

        {:ok, results}

      {:error, reason} ->
        Logger.warning("Failed to sample tile #{tile_x},#{tile_y}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Convert lat/lng to tile coordinates and pixel position
  defp lat_lng_to_tile_coords(lat, lng, zoom) do
    # Web Mercator projection (EPSG:3857)
    n = :math.pow(2, zoom)

    # Tile X coordinate
    tile_x = ((lng + 180.0) / 360.0 * n) |> floor()

    # Tile Y coordinate
    lat_rad = lat * :math.pi() / 180.0

    tile_y =
      ((1.0 - :math.log(:math.tan(lat_rad) + 1.0 / :math.cos(lat_rad)) / :math.pi()) / 2.0 * n)
      |> floor()

    # Pixel position within tile
    tile_x_frac = (lng + 180.0) / 360.0 * n - tile_x

    tile_y_frac =
      (1.0 - :math.log(:math.tan(lat_rad) + 1.0 / :math.cos(lat_rad)) / :math.pi()) / 2.0 * n -
        tile_y

    pixel_x = (tile_x_frac * @tile_size) |> floor() |> min(@tile_size - 1) |> max(0)
    pixel_y = (tile_y_frac * @tile_size) |> floor() |> min(@tile_size - 1) |> max(0)

    {tile_x, tile_y, pixel_x, pixel_y}
  end

  # Build RainViewer tile URL
  defp build_tile_url(tile_x, tile_y, zoom, timestamp) do
    # Format: {host}/v2/radar/{timestamp}/{tileSize}/{z}/{x}/{y}/{colorScheme}/{smooth}_{snow}.png
    "https://tilecache.rainviewer.com/v2/radar/#{timestamp}/#{@tile_size}/#{zoom}/#{tile_x}/#{tile_y}/#{@color_scheme}/#{@smooth}_#{@snow}.png"
  end

  # Download and decode tile image
  defp download_and_decode_tile(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: image_binary}} ->
        decode_image(image_binary)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Decode image binary to pixel data
  defp decode_image(image_binary) do
    case Vix.Vips.Image.new_from_buffer(image_binary) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, reason}
    end
  end

  # Get pixel color at position
  defp get_pixel_color(image_data, pixel_x, pixel_y) do
    case Vix.Vips.Image.get_pixel(image_data, pixel_x, pixel_y) do
      {:ok, [r, g, b, a]} -> {round(r), round(g), round(b), round(a)}
      {:ok, [r, g, b]} -> {round(r), round(g), round(b), 255}
      {:error, _reason} -> {0, 0, 0, 0}
    end
  end

  # Convert RGBA color to dBZ precipitation intensity
  # Based on Universal Blue color scheme (ID: 2)
  #
  # Key reference points from RainViewer's Universal Blue scheme:
  # - 20 dBZ: #00a3e0ff (Blue) - moderate rain
  # - 35 dBZ: #ffee00ff (Yellow) - heavy rain
  # - 50 dBZ: #c10000ff (Red) - very heavy rain
  # - 65+ dBZ: #ffffffff (White) - extreme precipitation
  defp color_to_dbz({_r, _g, _b, alpha}) when alpha < 10 do
    # Transparent = no precipitation
    0.0
  end

  defp color_to_dbz({r, g, b, _a}) do
    # Match against key colors in the Universal Blue scheme
    # and return approximate dBZ values

    cond do
      # White/very light (65+ dBZ) - extreme precipitation
      r > 240 and g > 240 and b > 240 ->
        65.0

      # Red tones (45-55 dBZ) - very heavy rain
      r > 180 and g < 50 and b < 50 ->
        50.0

      # Yellow/Orange tones (30-40 dBZ) - heavy rain
      r > 200 and g > 200 and b < 100 ->
        35.0

      # Bright green (25-35 dBZ) - moderate-heavy
      r < 100 and g > 150 and b < 100 ->
        30.0

      # Blue tones (15-25 dBZ) - moderate rain
      r < 100 and g > 100 and b > 150 ->
        20.0

      # Cyan/light blue (10-20 dBZ) - light rain
      r < 150 and g > 150 and b > 150 ->
        15.0

      # Dark/muted colors (0-10 dBZ) - very light precipitation
      r < 150 and g < 150 and b < 150 ->
        # Use average intensity as proxy for low precipitation
        avg_intensity = (r + g + b) / 3.0
        avg_intensity / 255.0 * 10.0

      # Default: estimate from overall brightness
      true ->
        avg_intensity = (r + g + b) / 3.0
        # Map brightness to 0-40 dBZ range
        avg_intensity / 255.0 * 40.0
    end
  end

  # Convert dBZ to mm/hr precipitation rate (approximate)
  # Using Marshall-Palmer Z-R relationship: Z = 200 * R^1.6
  # Where Z = 10^(dBZ/10), R = precipitation rate in mm/hr
  defp dbz_to_mm_per_hour(dbz) when dbz <= 0, do: 0.0

  defp dbz_to_mm_per_hour(dbz) do
    z = :math.pow(10, dbz / 10.0)
    # R = (Z / 200)^(1/1.6)
    r = :math.pow(z / 200.0, 1.0 / 1.6)
    # Return precipitation rate in mm/hr
    max(r, 0.0)
  end
end

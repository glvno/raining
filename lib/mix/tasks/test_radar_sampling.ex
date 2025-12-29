defmodule Mix.Tasks.TestRadarSampling do
  @moduledoc """
  Test radar tile sampling for a specific location.

  ## Usage

      # Test a specific location (e.g., Seattle area)
      mix test_radar_sampling 47.6 -122.3

      # Test with custom bounds
      mix test_radar_sampling 47.0 48.0 -123.0 -121.0
  """
  use Mix.Task

  alias Raining.Weather.RadarTileSampler
  alias Raining.Weather.ContourGenerator

  @shortdoc "Test radar tile sampling for a specific location"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {center_lat, center_lng, min_lat, max_lat, min_lng, max_lng} = parse_args(args)

    IO.puts("🔍 Testing radar tile sampling...")
    IO.puts("Center: #{center_lat}, #{center_lng}")
    IO.puts("Bounds: #{min_lat}° to #{max_lat}°N, #{min_lng}° to #{max_lng}°E\n")

    # Fetch current RainViewer timestamp
    IO.puts("Fetching latest radar timestamp...")
    timestamp = fetch_radar_timestamp()
    IO.puts("✓ Using radar timestamp: #{timestamp} (#{format_timestamp(timestamp)})\n")

    # Sample radar tiles
    IO.puts("Sampling radar tiles at 0.1° resolution...")

    case RadarTileSampler.sample_precipitation_grid(
           min_lat,
           max_lat,
           min_lng,
           max_lng,
           grid_step: 0.1,
           zoom: 6,
           timestamp: timestamp
         ) do
      {:ok, precip_data} ->
        IO.puts("✓ Found #{length(precip_data.points)} precipitation points\n")

        # Show sample points
        precip_data.points
        |> Enum.take(5)
        |> Enum.each(fn {lat, lng, precip_mm} ->
          IO.puts(
            "  • #{Float.round(lat, 2)}, #{Float.round(lng, 2)}: #{Float.round(precip_mm, 1)} mm/hr"
          )
        end)

        if length(precip_data.points) > 5 do
          IO.puts("  ... and #{length(precip_data.points) - 5} more points\n")
        else
          IO.puts("")
        end

        # Try to generate contour
        IO.puts("Generating contour polygon...")

        case ContourGenerator.generate_polygon(precip_data, center_lat, center_lng) do
          {:ok, polygon} ->
            {:ok, geojson} = Geo.JSON.encode(polygon)
            IO.puts("✓ Successfully generated contour polygon")
            IO.puts("\nGeoJSON (first 200 chars):")
            json_str = Jason.encode!(geojson, pretty: true)
            IO.puts(String.slice(json_str, 0, 200) <> "...")
            IO.puts("\n✅ Test successful!")

          {:error, reason} ->
            IO.puts("✗ Failed to generate contour: #{inspect(reason)}")
            IO.puts("\nThis might mean:")
            IO.puts("  • User location not within precipitation area")
            IO.puts("  • Try adjusting center coordinates to be within the rain area")
        end

      {:error, :no_precipitation} ->
        IO.puts("❌ No precipitation found in this area")
        IO.puts("\nTry a different location where it's currently raining!")
        IO.puts("Check https://www.rainviewer.com/ to see current precipitation.\n")

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}\n")
    end
  end

  defp parse_args([lat_str, lng_str]) do
    # Center point with 1 degree radius
    center_lat = String.to_float(lat_str)
    center_lng = String.to_float(lng_str)
    radius = 1.0

    {center_lat, center_lng, center_lat - radius, center_lat + radius, center_lng - radius,
     center_lng + radius}
  end

  defp parse_args([min_lat_str, max_lat_str, min_lng_str, max_lng_str]) do
    # Custom bounds
    min_lat = String.to_float(min_lat_str)
    max_lat = String.to_float(max_lat_str)
    min_lng = String.to_float(min_lng_str)
    max_lng = String.to_float(max_lng_str)
    center_lat = (min_lat + max_lat) / 2
    center_lng = (min_lng + max_lng) / 2
    {center_lat, center_lng, min_lat, max_lat, min_lng, max_lng}
  end

  defp parse_args(_) do
    IO.puts("Usage:")
    IO.puts("  mix test_radar_sampling <lat> <lng>")
    IO.puts("  mix test_radar_sampling <min_lat> <max_lat> <min_lng> <max_lng>")
    IO.puts("\nExamples:")
    IO.puts("  mix test_radar_sampling 47.6 -122.3  # Seattle area")
    IO.puts("  mix test_radar_sampling 40.7 -74.0   # New York area")
    IO.puts("  mix test_radar_sampling 51.5 -0.1    # London area")
    System.halt(1)
  end

  defp fetch_radar_timestamp do
    case Req.get("https://api.rainviewer.com/public/weather-maps.json") do
      {:ok, %{status: 200, body: %{"radar" => %{"past" => past}}}} ->
        latest = List.last(past)
        Map.get(latest, "time")

      _ ->
        DateTime.utc_now() |> DateTime.to_unix()
    end
  end

  defp format_timestamp(unix_timestamp) do
    DateTime.from_unix!(unix_timestamp) |> DateTime.to_string()
  end
end

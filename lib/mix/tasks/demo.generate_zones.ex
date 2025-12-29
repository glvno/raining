defmodule Mix.Tasks.Demo.GenerateZones do
  @moduledoc """
  Generates real precipitation zone polygons and mock droplets for demo mode.

  Uses the production Weather module and ContourGenerator to create authentic
  rain zone polygons from live precipitation data. Also generates randomized
  droplets within those zones.

  ## Usage

      mix demo.generate_zones

  Outputs TypeScript/JavaScript code ready to paste into frontend/src/data/demoData.ts
  """
  use Mix.Task

  alias Raining.Weather
  alias Raining.Weather.ContourGenerator

  @shortdoc "Generates real precipitation zone polygons and mock droplets for demo mode"

  @demo_locations [
    %{name: "Indiana", lat: 39.644, lng: -86.8645, droplet_count: 9},
    %{name: "Seattle", lat: 47.6, lng: -122.3, droplet_count: 3},
    %{name: "Singapore", lat: 1.3, lng: 103.85, droplet_count: 3}
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("🌧️  Generating precipitation zones from live weather data...\n")

    # Fetch current RainViewer timestamp
    radar_timestamp = fetch_radar_timestamp()

    # Generate polygons for each location
    zones =
      @demo_locations
      |> Enum.map(&generate_zone/1)
      |> Enum.filter(&(&1 != nil))

    if Enum.empty?(zones) do
      IO.puts("\n❌ No precipitation zones generated!")
      IO.puts("Try again later when there's active precipitation, or adjust location coordinates.\n")
      :ok
    else
      # Generate mock droplets within zones
      droplets = generate_droplets(zones)

      # Output formatted code
      output_demo_code(zones, droplets, radar_timestamp)
    end
  end

  defp generate_zone(%{name: name, lat: lat, lng: lng} = location) do
    IO.puts("Generating zone for #{name} (#{lat}, #{lng})...")

    # Calculate 2° bounding box
    {min_lat, max_lat, min_lng, max_lng} = calculate_bounds(lat, lng)

    case Weather.get_precipitation_grid(min_lat, max_lat, min_lng, max_lng) do
      {:ok, precip_data} ->
        case ContourGenerator.generate_polygon(precip_data, lat, lng) do
          {:ok, polygon} ->
            {:ok, geojson} = Geo.JSON.encode(polygon)
            IO.puts("✓ Generated polygon for #{name}\n")

            location
            |> Map.put(:polygon, geojson)
            |> Map.put(:raw_polygon, polygon)

          {:error, reason} ->
            IO.puts("✗ Failed to generate polygon for #{name}: #{inspect(reason)}\n")
            nil
        end

      {:error, reason} ->
        IO.puts("✗ No precipitation data for #{name}: #{inspect(reason)}\n")
        nil
    end
  end

  defp calculate_bounds(lat, lng) do
    radius = 2.0
    {lat - radius, lat + radius, lng - radius, lng + radius}
  end

  defp generate_droplets(zones) do
    IO.puts("Generating mock droplets within zones...\n")

    zones
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {zone, zone_idx} ->
      generate_droplets_for_zone(zone, zone_idx * 100)
    end)
  end

  defp generate_droplets_for_zone(
         %{name: name, droplet_count: count, raw_polygon: polygon},
         id_offset
       ) do
    IO.puts("Creating #{count} droplets for #{name}...")

    # Get bounding box of polygon
    bounds = get_polygon_bounds(polygon)

    # Generate random points within polygon
    1..count
    |> Enum.map(fn idx ->
      {lat, lng} = generate_random_point_in_polygon(polygon, bounds)

      %{
        id: id_offset + idx,
        latitude: lat,
        longitude: lng,
        content: generate_droplet_content(name, idx),
        user: %{
          id: id_offset + idx,
          email: "user#{idx}@#{String.downcase(name)}.local"
        },
        # Spread droplets across last 2 hours
        minutes_ago: :rand.uniform(120)
      }
    end)
  end

  defp get_polygon_bounds(%Geo.Polygon{coordinates: [coords | _]}) do
    lats = Enum.map(coords, &elem(&1, 1))
    lngs = Enum.map(coords, &elem(&1, 0))

    {Enum.min(lats), Enum.max(lats), Enum.min(lngs), Enum.max(lngs)}
  end

  defp generate_random_point_in_polygon(polygon, {min_lat, max_lat, min_lng, max_lng}) do
    # Simple rejection sampling - generate random points until one is inside polygon
    point = {
      min_lat + :rand.uniform() * (max_lat - min_lat),
      min_lng + :rand.uniform() * (max_lng - min_lng)
    }

    if point_in_polygon?(point, polygon) do
      point
    else
      generate_random_point_in_polygon(polygon, {min_lat, max_lat, min_lng, max_lng})
    end
  end

  defp point_in_polygon?({lat, lng}, %Geo.Polygon{coordinates: [coords | _]}) do
    # Ray casting algorithm
    inside =
      coords
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(false, fn [{x1, y1}, {x2, y2}], acc ->
        if (y1 > lat) != (y2 > lat) and
             lng < (x2 - x1) * (lat - y1) / (y2 - y1) + x1 do
          not acc
        else
          acc
        end
      end)

    inside
  end

  defp generate_droplet_content(location, idx) do
    contents = %{
      "Indiana" => [
        "Intense rainfall here! 37mm and counting ⛈️",
        "Heavy rain just started! Lightning everywhere ⚡",
        "Storm moving through fast! Visibility is terrible",
        "Major downpour in the area! 🌧️",
        "Rain picking up intensity here! Stay safe everyone!",
        "Steady rain here, roads starting to puddle 💧",
        "Thunder rolling through! The storm is here 💥",
        "Light rain continuing 🌧️",
        "Clouds building up, rain starting to fall 🌦️"
      ],
      "Seattle" => [
        "Classic Seattle drizzle! ☔",
        "Rain hitting the Puget Sound hard right now 🌊",
        "Another rainy day in the PNW! Coffee weather ☕"
      ],
      "Singapore" => [
        "Tropical downpour! 🌴⛈️",
        "Monsoon season intensity! Streets flooding 💧",
        "Heavy rain near Marina Bay! 🏙️"
      ]
    }

    location_contents = Map.get(contents, location, ["Rain detected!"])
    Enum.at(location_contents, rem(idx - 1, length(location_contents)))
  end

  defp fetch_radar_timestamp do
    case Req.get("https://api.rainviewer.com/public/weather-maps.json") do
      {:ok, %{status: 200, body: %{"radar" => %{"past" => past}}}} ->
        latest = List.last(past)
        Map.get(latest, "time")

      _ ->
        # Fallback to current Unix timestamp
        DateTime.utc_now() |> DateTime.to_unix()
    end
  end

  defp output_demo_code(zones, droplets, radar_timestamp) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("COPY THE FOLLOWING INTO frontend/src/data/demoData.ts")
    IO.puts(String.duplicate("=", 80) <> "\n")

    IO.puts("// Generated on #{now}")
    IO.puts("// Radar timestamp: #{radar_timestamp}\n")

    # Output droplets
    IO.puts("export const DEMO_FEED_DATA: FeedResponse = {")
    IO.puts("  droplets: [")

    droplets
    |> Enum.with_index()
    |> Enum.each(fn {droplet, idx} ->
      output_droplet(droplet)
      if idx < length(droplets) - 1, do: IO.puts(",")
    end)

    IO.puts("  ],")
    IO.puts("  count: #{length(droplets)},")
    IO.puts("  time_window_hours: 2,")
    IO.puts("  rain_zone: DEMO_GLOBAL_RAIN_ZONES[0],  // First zone (usually Indiana)")
    IO.puts("};\n")

    # Output radar timestamp
    IO.puts("export const DEMO_RADAR_TIMESTAMP = #{radar_timestamp};\n")

    # Output zones
    IO.puts("export const DEMO_GLOBAL_RAIN_ZONES = [")

    zones
    |> Enum.with_index()
    |> Enum.each(fn {zone, idx} ->
      IO.puts("  // #{zone.name} rain zone")
      IO.puts("  #{Jason.encode!(zone.polygon, pretty: true)}")
      if idx < length(zones) - 1, do: IO.puts(",")
    end)

    IO.puts("];")
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("\nNext steps:")
    IO.puts("1. Copy the output above into frontend/src/data/demoData.ts")
    IO.puts("2. Rebuild the frontend: cd frontend && npm run build")
    IO.puts("3. Test in demo mode: visit /deluge?demo=true\n")
  end

  defp output_droplet(droplet) do
    # Escape single quotes in content
    escaped_content = String.replace(droplet.content, "'", "\\'")

    IO.puts("    {")
    IO.puts("      id: #{droplet.id},")
    IO.puts("      content: '#{escaped_content}',")
    IO.puts("      latitude: #{droplet.latitude},")
    IO.puts("      longitude: #{droplet.longitude},")
    IO.puts("      user: {")
    IO.puts("        id: #{droplet.user.id},")
    IO.puts("        email: '#{droplet.user.email}',")
    IO.puts("      },")

    IO.puts(
      "      inserted_at: new Date(Date.now() - #{droplet.minutes_ago} * 60 * 1000).toISOString(),"
    )

    IO.puts(
      "      updated_at: new Date(Date.now() - #{droplet.minutes_ago} * 60 * 1000).toISOString(),"
    )

    IO.puts("    }")
  end
end

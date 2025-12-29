defmodule Mix.Tasks.Demo.GenerateZones do
  @moduledoc """
  Captures a precipitation snapshot and automatically identifies distinct rainy regions.

  Fetches live precipitation data, uses clustering to find 3 significant rain areas,
  generates contour polygons, creates demo droplets, and stores everything in the database.

  ## Usage

      mix demo.generate_zones

  Stores snapshots in database for demo mode. No manual copy-paste needed!
  """
  use Mix.Task

  alias Raining.Weather
  alias Raining.Weather.ContourGenerator
  alias Raining.Weather.RegionDetector
  alias Raining.Demo

  @shortdoc "Captures precipitation snapshot and auto-detects rainy regions for demo mode"

  # Multiple scan areas - ONE API call per continent (coarse grid prevents 414 errors)
  # We'll combine results and use clustering to find 3 distinct regions globally
  @scan_areas [
    %{
      name: "North America",
      min_lat: 25.0,
      max_lat: 50.0,
      min_lng: -125.0,
      max_lng: -65.0,
      grid_step: 2.0
    },
    %{
      name: "South America",
      min_lat: -35.0,
      max_lat: 10.0,
      min_lng: -80.0,
      max_lng: -35.0,
      grid_step: 2.5
    },
    %{
      name: "Europe",
      min_lat: 35.0,
      max_lat: 60.0,
      min_lng: -10.0,
      max_lng: 40.0,
      grid_step: 2.0
    },
    %{
      name: "Asia-Pacific",
      min_lat: -10.0,
      max_lat: 40.0,
      min_lng: 95.0,
      max_lng: 145.0,
      grid_step: 3.0
    }
  ]

  @droplet_count_per_region 5

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("🌧️  Capturing precipitation snapshot and detecting rainy regions...\n")

    # Fetch current RainViewer timestamp
    radar_timestamp = fetch_radar_timestamp()

    # Fetch precipitation data from all continents (one API call per continent)
    all_precip_points = fetch_precipitation_from_continents()

    if Enum.empty?(all_precip_points) do
      IO.puts("\n❌ No significant precipitation found globally!")
      IO.puts("Try again later when there's more active precipitation worldwide.\n")
      :ok
    else
      IO.puts("✓ Found #{length(all_precip_points)} precipitation points\n")

      # Identify 3 distinct rainy regions using clustering
      IO.puts("🔍 Detecting distinct rainy regions...")
      regions = RegionDetector.find_top_regions(all_precip_points, count: 3, min_cluster_size: 15)

      if length(regions) < 3 do
        IO.puts(
          "\n⚠️  Only found #{length(regions)} significant regions. Need at least 3 for demo mode."
        )

        IO.puts("Try again later when there's more widespread precipitation.\n")
        :ok
      else
        IO.puts("✓ Identified #{length(regions)} distinct regions\n")

        # Generate zones and droplets for each region
        zones =
          regions
          |> Enum.map(&generate_zone_for_region/1)
          |> Enum.filter(&(&1 != nil))

        if Enum.empty?(zones) do
          IO.puts("\n❌ Failed to generate valid zones from detected regions!")
          :ok
        else
          # Generate mock droplets within zones
          droplets = generate_droplets(zones)

          # Output formatted code (for reference/backup)
          output_demo_code(zones, droplets, radar_timestamp)

          IO.puts("\n✅ Demo data successfully stored in database!")
          IO.puts("Run the app and visit /deluge?demo=true to see your demo zones.\n")
        end
      end
    end
  end

  # Fetch precipitation data from all continents (ONE API call per continent)
  defp fetch_precipitation_from_continents do
    @scan_areas
    |> Enum.flat_map(fn area ->
      IO.puts("Scanning #{area.name} for precipitation...")
      IO.puts(
        "  Area: #{area.min_lat}°N to #{area.max_lat}°N, #{area.min_lng}°E to #{area.max_lng}°E (grid: #{area.grid_step}°)"
      )

      # Use custom grid step per area to prevent 414 URI Too Long errors
      # Larger areas use coarser grids to keep URL manageable
      case Weather.get_precipitation_grid(
             area.min_lat,
             area.max_lat,
             area.min_lng,
             area.max_lng,
             grid_step: area.grid_step,
             threshold: 0.3
           ) do
        {:ok, precip_data} ->
          IO.puts("  ✓ Found #{length(precip_data.points)} precipitation points\n")
          precip_data.points

        {:error, reason} ->
          IO.puts("  ✗ Error: #{inspect(reason)}\n")
          []
      end
    end)
  end

  # Generate zone (polygon + droplets) for a detected region
  defp generate_zone_for_region(region) do
    {center_lat, center_lng} = region.center
    name = region.name

    IO.puts("Generating zone for #{name} (center: #{center_lat}, #{center_lng})...")
    IO.puts("  Points: #{region.point_count}, Total precip: #{Float.round(region.total_precip, 1)}mm")

    # Prepare precipitation data for ContourGenerator
    precip_data = %{
      points: region.points,
      bounds: calculate_bounds_from_points(region.points)
    }

    case ContourGenerator.generate_polygon(precip_data, center_lat, center_lng) do
      {:ok, polygon} ->
        {:ok, geojson} = Geo.JSON.encode(polygon)
        IO.puts("  ✓ Generated polygon for #{name}")

        # Store snapshot in database
        snapshot_timestamp = DateTime.utc_now()

        case Demo.store_radar_snapshot(%{
               region_name: name,
               snapshot_timestamp: snapshot_timestamp,
               center_lat: center_lat,
               center_lng: center_lng,
               precipitation_grid: %{points: region.points},
               metadata: %{
                 max_precip_mm: region.max_precip,
                 total_precip_mm: region.total_precip,
                 point_count: region.point_count
               }
             }) do
          {:ok, _snapshot} ->
            IO.puts("  ✓ Stored snapshot for #{name} in database\n")

          {:error, changeset} ->
            IO.puts("  ✗ Failed to store snapshot for #{name}: #{inspect(changeset.errors)}\n")
        end

        %{
          name: name,
          lat: center_lat,
          lng: center_lng,
          droplet_count: @droplet_count_per_region,
          polygon: geojson,
          raw_polygon: polygon
        }

      {:error, reason} ->
        IO.puts("  ✗ Failed to generate polygon for #{name}: #{inspect(reason)}\n")
        nil
    end
  end

  # Calculate bounding box from list of precipitation points
  defp calculate_bounds_from_points(points) do
    lats = Enum.map(points, &elem(&1, 0))
    lngs = Enum.map(points, &elem(&1, 1))

    {Enum.min(lats), Enum.max(lats), Enum.min(lngs), Enum.max(lngs)}
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
          email: "user#{id_offset + idx}@demo.local"
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

  defp generate_droplet_content(_location, idx) do
    # Generic rain-related content for auto-detected regions
    contents = [
      "Intense rainfall here! Heavy downpour ⛈️",
      "Rain just started! Getting heavier by the minute ⚡",
      "Storm moving through fast! Stay safe everyone 🌧️",
      "Major precipitation in the area! Roads are wet 💧",
      "Rain picking up intensity! Umbrellas out ☔",
      "Steady rain here, puddles forming everywhere 💦",
      "Thunder rolling through! Nature's symphony 💥",
      "Light rain continuing, fresh smell in the air 🌧️",
      "Clouds building up, rain started falling 🌦️",
      "Beautiful rain shower! Loving this weather 🌈",
      "Caught in the rain! Classic weather moment ☁️",
      "Rain dropping steadily, perfect cozy weather 🏠",
      "Storm clouds overhead! Rain incoming 🌩️",
      "Drizzle turning into proper rain now 🌊",
      "Heavy precipitation! Nature doing its thing 🍃"
    ]

    Enum.at(contents, rem(idx - 1, length(contents)))
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

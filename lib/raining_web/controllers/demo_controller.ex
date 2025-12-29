defmodule RainingWeb.DemoController do
  use RainingWeb, :controller

  alias Raining.Demo

  @doc """
  GET /api/demo/zones

  Returns demo rain zones generated from stored radar snapshots.

  ## Query Parameters

    - `regions` (optional) - Comma-separated list of region names to fetch
                             (e.g., "Indiana,Seattle,Singapore")
                             Defaults to all available regions.

  ## Response

  Returns JSON with the following structure:

      {
        "zones": [
          {
            "region": "Indiana",
            "snapshot_timestamp": "2024-12-28T22:35:00Z",
            "rain_zone": {
              "type": "Polygon",
              "coordinates": [[[-86.8, 39.6], ...]]
            },
            "metadata": {
              "max_precip_mm": 37.8,
              "point_count": 156
            }
          },
          ...
        ],
        "metadata": {
          "total_zones": 3,
          "generated_at": "2024-12-29T..."
        }
      }

  ## Examples

      # Get all demo zones
      GET /api/demo/zones

      # Get specific regions
      GET /api/demo/zones?regions=Indiana,Seattle
  """
  def zones(conn, params) do
    regions = parse_regions(params["regions"])
    zones = Demo.get_demo_zones(regions: regions)

    json(conn, %{
      zones: zones,
      metadata: %{
        total_zones: length(zones),
        generated_at: DateTime.utc_now()
      }
    })
  end

  # Parse comma-separated region names from query parameter
  defp parse_regions(nil), do: nil

  defp parse_regions(regions_param) when is_binary(regions_param) do
    regions_param
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_regions(_), do: nil
end

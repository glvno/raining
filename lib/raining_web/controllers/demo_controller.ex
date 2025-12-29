defmodule RainingWeb.DemoController do
  use RainingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Raining.Demo
  alias RainingWeb.Schemas.DemoZonesResponse

  tags ["Demo"]

  operation :zones,
    summary: "Get demo rain zones",
    description: """
    Returns demo rain zones generated from stored radar snapshots.
    This endpoint is public and does not require authentication.
    Useful for testing and demonstration purposes.
    """,
    parameters: [
      regions: [
        in: :query,
        description: "Comma-separated list of region names (e.g., 'Indiana,Seattle,Singapore'). Defaults to all regions.",
        type: :string,
        required: false,
        example: "Indiana,Seattle"
      ]
    ],
    responses: [
      ok: {"Demo zones", "application/json", DemoZonesResponse}
    ]

  @doc """
  GET /api/demo/zones

  Returns demo rain zones generated from stored radar snapshots.
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

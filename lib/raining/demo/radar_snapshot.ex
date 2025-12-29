defmodule Raining.Demo.RadarSnapshot do
  @moduledoc """
  Schema for storing historical radar/precipitation snapshots.

  Stores precipitation grid data with timestamps for reproducible demo zones.
  The precipitation grid can be used with ContourGenerator to create rain area
  polygons on-demand.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "radar_snapshots" do
    field :snapshot_timestamp, :utc_datetime
    field :region_name, :string
    field :center_lat, :float
    field :center_lng, :float
    field :precipitation_grid, :map
    field :grid_resolution, :float, default: 0.5
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(radar_snapshot, attrs) do
    radar_snapshot
    |> cast(attrs, [
      :snapshot_timestamp,
      :region_name,
      :center_lat,
      :center_lng,
      :precipitation_grid,
      :grid_resolution,
      :metadata
    ])
    |> validate_required([
      :snapshot_timestamp,
      :region_name,
      :center_lat,
      :center_lng,
      :precipitation_grid
    ])
    |> validate_number(:center_lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:center_lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:grid_resolution, greater_than: 0)
    |> unique_constraint([:region_name, :snapshot_timestamp])
  end
end

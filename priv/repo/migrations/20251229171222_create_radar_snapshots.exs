defmodule Raining.Repo.Migrations.CreateRadarSnapshots do
  use Ecto.Migration

  def change do
    create table(:radar_snapshots) do
      add :snapshot_timestamp, :utc_datetime, null: false
      add :region_name, :string, null: false
      add :center_lat, :float, null: false
      add :center_lng, :float, null: false
      add :precipitation_grid, :jsonb, null: false
      add :grid_resolution, :float, default: 0.5
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    create unique_index(:radar_snapshots, [:region_name, :snapshot_timestamp])
    create index(:radar_snapshots, [:snapshot_timestamp])
  end
end

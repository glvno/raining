defmodule Raining.Repo.Migrations.AddNwsZoneCaching do
  use Ecto.Migration

  def change do
    alter table(:rain_status_cache) do
      # Add NWS-specific fields
      add :zone_id, :string
      add :zone_name, :string
      add :geometry, :geometry
      add :last_checked, :utc_datetime

      # Make latitude/longitude nullable (zone-based, not point-based)
      modify :latitude, :float, null: true
      modify :longitude, :float, null: true
    end

    # Add spatial index for fast point-in-polygon queries
    execute "CREATE INDEX rain_status_cache_geometry_idx ON rain_status_cache USING GIST (geometry)",
            "DROP INDEX rain_status_cache_geometry_idx"

    # Add unique index on zone_id for lookups and uniqueness constraint
    create unique_index(:rain_status_cache, [:zone_id])
  end
end

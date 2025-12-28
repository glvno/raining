defmodule Raining.Repo.Migrations.CreateRainStatusCache do
  use Ecto.Migration

  def change do
    create table(:rain_status_cache) do
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :is_raining, :boolean, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # Index for efficient lookups by location and expiration
    create index(:rain_status_cache, [:latitude, :longitude, :expires_at])

    # Index for cleaning up expired entries
    create index(:rain_status_cache, [:expires_at])
  end
end

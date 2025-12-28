defmodule Raining.Repo.Migrations.AddRainCoordsToCache do
  use Ecto.Migration

  def change do
    alter table(:rain_status_cache) do
      # Store rain area coordinates as JSON array of [lat, lng] tuples
      add :rain_coords, :map
    end
  end
end

defmodule Raining.Droplets.RainStatusCache do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "rain_status_cache" do
    # NWS zone-based fields
    field :zone_id, :string
    field :zone_name, :string
    field :geometry, Geo.PostGIS.Geometry
    field :last_checked, :utc_datetime

    # Legacy coordinate-based fields (kept for backward compatibility)
    field :latitude, :float
    field :longitude, :float
    field :rain_coords, :map

    # Common fields
    field :is_raining, :boolean
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating rain status cache entries.

  Supports both zone-based (NWS) and coordinate-based (Open-Meteo) entries.
  """
  def changeset(cache, attrs) do
    cache
    |> cast(attrs, [
      :zone_id,
      :zone_name,
      :geometry,
      :last_checked,
      :latitude,
      :longitude,
      :is_raining,
      :rain_coords,
      :expires_at
    ])
    |> validate_required([:is_raining, :expires_at])
    |> unique_constraint(:zone_id)
  end

  @doc """
  Query to find valid (non-expired) cache entry for given coordinates.

  Uses a tolerance of 0.1 degrees (~11km) to match nearby coordinates.
  """
  def get_valid_cache_query(latitude, longitude) do
    tolerance = 0.1
    now = DateTime.utc_now()

    from c in __MODULE__,
      where:
        c.latitude >= ^(latitude - tolerance) and
          c.latitude <= ^(latitude + tolerance) and
          c.longitude >= ^(longitude - tolerance) and
          c.longitude <= ^(longitude + tolerance) and
          c.expires_at > ^now,
      order_by: [desc: c.inserted_at],
      limit: 1
  end

  @doc """
  Query to delete expired cache entries.
  """
  def expired_entries_query do
    now = DateTime.utc_now()

    from c in __MODULE__,
      where: c.expires_at <= ^now
  end
end

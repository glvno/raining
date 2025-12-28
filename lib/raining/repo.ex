defmodule Raining.Repo do
  use Ecto.Repo,
    otp_app: :raining,
    adapter: Ecto.Adapters.Postgres

  # Define PostGIS types for Ecto
  Postgrex.Types.define(Raining.PostgresTypes,
    [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
    json: Jason
  )
end

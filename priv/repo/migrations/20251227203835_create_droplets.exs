defmodule Raining.Repo.Migrations.CreateDroplets do
  use Ecto.Migration

  def change do
    create table(:droplets) do
      add :content, :text, null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:droplets, [:user_id])
    create index(:droplets, [:inserted_at])
  end
end

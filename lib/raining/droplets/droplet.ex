defmodule Raining.Droplets.Droplet do
  @moduledoc """
  A droplet is a social post created by a user at a specific geolocation.

  Droplets are displayed in a local feed showing only posts from the same
  contiguous rain area within a configurable time window.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Raining.Accounts.User

  schema "droplets" do
    field :content, :string
    field :latitude, :float
    field :longitude, :float
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a droplet.

  Validates:
  - All fields are required
  - Content length between 1 and 500 characters
  - Latitude between -90 and 90 degrees
  - Longitude between -180 and 180 degrees
  - User exists (foreign key constraint)
  """
  def changeset(droplet, attrs) do
    droplet
    |> cast(attrs, [:content, :latitude, :longitude, :user_id])
    |> validate_required([:content, :latitude, :longitude, :user_id])
    |> validate_length(:content, min: 1, max: 500)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> foreign_key_constraint(:user_id)
  end
end

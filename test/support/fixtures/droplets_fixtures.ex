defmodule Raining.DropletsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Raining.Droplets` context.
  """

  alias Raining.Droplets

  @doc """
  Generate a droplet with random coordinates near a default location.

  Coordinates will vary slightly around (52.5, 13.4) to simulate
  different droplets in a geographic area.

  ## Examples

      iex> droplet_fixture()
      %Droplet{content: "Test droplet content", ...}

      iex> droplet_fixture(%{content: "Custom content"})
      %Droplet{content: "Custom content", ...}

  """
  def droplet_fixture(attrs \\ %{}) do
    # Create a user if not provided
    user_id =
      case Map.get(attrs, :user_id) do
        nil ->
          user = Raining.AccountsFixtures.unconfirmed_user_fixture()
          user.id

        user_id ->
          user_id
      end

    # Generate random coordinates near Berlin (52.5, 13.4)
    # Add random offset between -0.5 and +0.5 degrees
    base_lat = 52.5
    base_lng = 13.4
    random_lat_offset = :rand.uniform() - 0.5
    random_lng_offset = :rand.uniform() - 0.5

    {:ok, droplet} =
      attrs
      |> Enum.into(%{
        content: "Test droplet content",
        latitude: base_lat + random_lat_offset,
        longitude: base_lng + random_lng_offset,
        user_id: user_id
      })
      |> Droplets.create_droplet()

    droplet
  end

  @doc """
  Generate a droplet at specific coordinates.

  Useful for testing location-based features.

  ## Examples

      iex> droplet_at_location(52.5, 13.4)
      %Droplet{latitude: 52.5, longitude: 13.4}

  """
  def droplet_at_location(latitude, longitude, attrs \\ %{}) do
    droplet_fixture(
      Map.merge(attrs, %{
        latitude: latitude,
        longitude: longitude
      })
    )
  end
end

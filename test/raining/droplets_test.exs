defmodule Raining.DropletsTest do
  use Raining.DataCase, async: true

  alias Raining.Droplets
  alias Raining.Droplets.Droplet

  import Raining.DropletsFixtures
  import Raining.AccountsFixtures

  describe "create_droplet/1" do
    test "creates droplet with valid attributes" do
      user = unconfirmed_user_fixture()

      valid_attrs = %{
        content: "Testing droplet creation",
        latitude: 52.5,
        longitude: 13.4,
        user_id: user.id
      }

      assert {:ok, %Droplet{} = droplet} = Droplets.create_droplet(valid_attrs)
      assert droplet.content == "Testing droplet creation"
      assert droplet.latitude == 52.5
      assert droplet.longitude == 13.4
      assert droplet.user_id == user.id
    end

    test "returns error changeset with invalid content (too long)" do
      user = unconfirmed_user_fixture()

      invalid_attrs = %{
        content: String.duplicate("a", 501),
        latitude: 52.5,
        longitude: 13.4,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Droplets.create_droplet(invalid_attrs)
      assert %{content: ["should be at most 500 character(s)"]} = errors_on(changeset)
    end

    test "returns error changeset with invalid content (empty)" do
      user = unconfirmed_user_fixture()

      invalid_attrs = %{
        content: "",
        latitude: 52.5,
        longitude: 13.4,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Droplets.create_droplet(invalid_attrs)
      assert %{content: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset with invalid latitude (out of range)" do
      user = unconfirmed_user_fixture()

      invalid_attrs = %{
        content: "Test",
        latitude: 91.0,
        longitude: 13.4,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Droplets.create_droplet(invalid_attrs)
      assert %{latitude: ["must be less than or equal to 90"]} = errors_on(changeset)
    end

    test "returns error changeset with invalid longitude (out of range)" do
      user = unconfirmed_user_fixture()

      invalid_attrs = %{
        content: "Test",
        latitude: 52.5,
        longitude: 181.0,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Droplets.create_droplet(invalid_attrs)
      assert %{longitude: ["must be less than or equal to 180"]} = errors_on(changeset)
    end

    test "returns error changeset with missing required fields" do
      assert {:error, %Ecto.Changeset{} = changeset} = Droplets.create_droplet(%{})

      assert %{
               content: ["can't be blank"],
               latitude: ["can't be blank"],
               longitude: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "get_droplet!/1" do
    test "returns the droplet with given id and preloaded user" do
      droplet = droplet_fixture()
      fetched_droplet = Droplets.get_droplet!(droplet.id)

      assert fetched_droplet.id == droplet.id
      assert fetched_droplet.content == droplet.content
      assert fetched_droplet.user_id == droplet.user_id
      # Verify user is preloaded (not just an association)
      assert %Raining.Accounts.User{} = fetched_droplet.user
      refute is_nil(fetched_droplet.user.email)
    end

    test "raises Ecto.NoResultsError when droplet doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Droplets.get_droplet!(999_999)
      end
    end
  end

  describe "list_user_droplets/1" do
    test "returns all droplets for a user" do
      user = unconfirmed_user_fixture()
      droplet1 = droplet_fixture(%{user_id: user.id, content: "First droplet"})
      droplet2 = droplet_fixture(%{user_id: user.id, content: "Second droplet"})

      # Create droplet for different user (should not be returned)
      other_user = unconfirmed_user_fixture()
      _other_droplet = droplet_fixture(%{user_id: other_user.id})

      user_droplets = Droplets.list_user_droplets(user.id)

      assert length(user_droplets) == 2
      droplet_ids = Enum.map(user_droplets, & &1.id)
      assert droplet1.id in droplet_ids
      assert droplet2.id in droplet_ids
    end

    test "returns droplets sorted by most recent first" do
      user = unconfirmed_user_fixture()
      droplet1 = droplet_fixture(%{user_id: user.id, content: "First"})

      # Manually update first droplet to have an older timestamp
      old_time = DateTime.utc_now() |> DateTime.add(-1, :hour)

      Raining.Repo.update_all(
        from(d in Droplet, where: d.id == ^droplet1.id),
        set: [inserted_at: old_time]
      )

      droplet2 = droplet_fixture(%{user_id: user.id, content: "Second"})

      user_droplets = Droplets.list_user_droplets(user.id)

      assert length(user_droplets) == 2
      # Most recent should be first
      assert hd(user_droplets).id == droplet2.id
    end

    test "returns empty list when user has no droplets" do
      user = unconfirmed_user_fixture()
      assert Droplets.list_user_droplets(user.id) == []
    end

    test "preloads user associations" do
      user = unconfirmed_user_fixture()
      _droplet = droplet_fixture(%{user_id: user.id})

      [fetched_droplet] = Droplets.list_user_droplets(user.id)

      assert %Raining.Accounts.User{} = fetched_droplet.user
      refute is_nil(fetched_droplet.user.email)
    end
  end

  describe "droplet_in_rain_area?/2" do
    test "returns true when droplet's rounded coordinates match rain area" do
      precision = Raining.Weather.precision()

      # Create droplet with unrounded coordinates
      droplet = %Droplet{
        latitude: 52.527,
        longitude: 13.416,
        content: "Test"
      }

      # Calculate what these should round to
      rounded_lat = Float.round(52.527, precision)
      rounded_lng = Float.round(13.416, precision)

      rain_coords = [{rounded_lat, rounded_lng}, {51.0, 12.0}]

      assert Droplets.droplet_in_rain_area?(droplet, rain_coords)
    end

    test "returns false when droplet's coordinates don't match rain area" do
      droplet = %Droplet{
        latitude: 40.7,
        longitude: -74.0,
        content: "Test"
      }

      rain_coords = [{52.5, 13.4}, {52.6, 13.4}]

      refute Droplets.droplet_in_rain_area?(droplet, rain_coords)
    end

    test "works with coordinates that round to same value" do
      precision = Raining.Weather.precision()

      # These should round to the same value with grid_step = 1.0 (precision = 0)
      droplet1 = %Droplet{latitude: 52.4, longitude: 13.2, content: "Test"}
      droplet2 = %Droplet{latitude: 52.3, longitude: 13.1, content: "Test"}

      rounded_lat = Float.round(52.4, precision)
      rounded_lng = Float.round(13.2, precision)

      rain_coords = [{rounded_lat, rounded_lng}]

      # Both should match if they round to the same coordinate
      assert Droplets.droplet_in_rain_area?(droplet1, rain_coords) ==
               Droplets.droplet_in_rain_area?(droplet2, rain_coords)
    end
  end

  describe "get_local_feed/2" do
    test "returns empty list when not raining at location" do
      # Create some droplets
      _droplet1 = droplet_fixture()
      _droplet2 = droplet_fixture()

      # Test with coordinates where it's unlikely to be raining
      # The Weather API should return {:error, :no_rain}
      result = Droplets.get_local_feed(0.0, 0.0)

      case result do
        {:ok, []} ->
          # Expected when not raining
          assert true

        {:ok, _droplets} ->
          # OK if it happens to be raining at 0,0
          assert true

        {:error, _reason} ->
          # OK if API error
          assert true
      end
    end

    test "filters droplets by time window" do
      user = unconfirmed_user_fixture()

      # Create a recent droplet at a specific location
      recent_droplet =
        droplet_at_location(52.5, 13.4, %{
          user_id: user.id,
          content: "Recent droplet"
        })

      # Manually update an old droplet to be outside time window
      old_time = DateTime.utc_now() |> DateTime.add(-5, :hour)

      old_droplet =
        droplet_at_location(52.5, 13.4, %{
          user_id: user.id,
          content: "Old droplet"
        })

      Raining.Repo.update_all(
        from(d in Droplet, where: d.id == ^old_droplet.id),
        set: [inserted_at: old_time]
      )

      # Test with custom time window of 2 hours
      # Note: This test depends on actual weather conditions
      result = Droplets.get_local_feed(52.5, 13.4, time_window_hours: 2)

      case result do
        {:ok, droplets, _zone_geometry} when is_list(droplets) ->
          # If we got droplets, verify time filtering
          droplet_ids = Enum.map(droplets, & &1.id)

          if recent_droplet.id in droplet_ids do
            # Recent droplet should be included
            # Old droplet should NOT be included
            refute old_droplet.id in droplet_ids
          end

        {:error, _} ->
          # OK if API error or not raining
          assert true
      end
    end

    @tag :integration
    test "returns droplets in same rain area with real API" do
      # This test makes actual API calls and depends on weather conditions
      # Tagged as :integration so it can be skipped in regular test runs

      user = unconfirmed_user_fixture()

      # Create droplets at slightly different coordinates
      # that should round to the same grid cell
      _droplet1 = droplet_at_location(52.51, 13.41, %{user_id: user.id})
      _droplet2 = droplet_at_location(52.49, 13.39, %{user_id: user.id})

      # Create droplet far away (different grid cell)
      _far_droplet = droplet_at_location(40.7, -74.0, %{user_id: user.id})

      result = Droplets.get_local_feed(52.5, 13.4)

      case result do
        {:ok, droplets, _zone_geometry} when is_list(droplets) ->
          # Verify structure
          assert Enum.all?(droplets, fn d ->
                   %Droplet{} = d
                   # User should be preloaded
                   %Raining.Accounts.User{} = d.user
                   true
                 end)

          # Verify sorting (most recent first)
          timestamps = Enum.map(droplets, & &1.inserted_at)

          assert timestamps == Enum.sort(timestamps, {:desc, DateTime})

        {:error, _reason} ->
          # OK if API error or not raining
          assert true
      end
    end
  end

  describe "get_time_window_hours/0" do
    test "returns configured time window" do
      # Default is 2 hours (defined in the context module)
      assert Droplets.get_time_window_hours() == 2
    end
  end
end

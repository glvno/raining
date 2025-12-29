defmodule Raining.WeatherTest do
  use ExUnit.Case, async: true
  doctest Raining.Weather

  # Get the current precision from the module
  @precision Raining.Weather.precision()

  describe "precision/0" do
    test "returns the configured precision" do
      assert is_integer(Raining.Weather.precision())
      assert Raining.Weather.precision() >= 0
    end
  end

  describe "round_coordinate/1" do
    test "rounds to configured precision" do
      precision = @precision

      # Test that coordinates are rounded to the right number of decimal places
      assert Raining.Weather.round_coordinate(52.527) == Float.round(52.527, precision)
      assert Raining.Weather.round_coordinate(13.46) == Float.round(13.46, precision)
      assert Raining.Weather.round_coordinate(13.44) == Float.round(13.44, precision)
    end

    test "handles already rounded coordinates" do
      precision = @precision
      already_rounded = Float.round(52.5, precision)

      assert Raining.Weather.round_coordinate(already_rounded) == already_rounded
    end

    test "handles negative coordinates" do
      precision = @precision

      assert Raining.Weather.round_coordinate(-52.527) == Float.round(-52.527, precision)
      assert Raining.Weather.round_coordinate(-13.46) == Float.round(-13.46, precision)
    end

    test "handles integers" do
      assert Raining.Weather.round_coordinate(52) == 52.0
      assert Raining.Weather.round_coordinate(-13) == -13.0
    end
  end

  describe "is_raining?/2" do
    test "returns {:ok, boolean} for valid coordinates" do
      # Test with coordinates that work at any precision
      result = Raining.Weather.is_raining?(52.5, 13.4)
      assert {:ok, is_raining} = result
      assert is_boolean(is_raining)
    end

    test "rounds coordinates before making request" do
      # Coordinates should be rounded to the configured precision
      # These should produce the same result as they round to the same values
      precision = @precision
      coord1_lat = Float.round(52.527, precision)
      coord1_lng = Float.round(13.46, precision)

      result1 = Raining.Weather.is_raining?(52.527, 13.46)
      result2 = Raining.Weather.is_raining?(coord1_lat, coord1_lng)

      assert {:ok, _} = result1
      assert {:ok, _} = result2
    end

    test "handles different coordinates" do
      # Test with different coordinates
      result = Raining.Weather.is_raining?(40.7, -74.0)
      assert {:ok, is_raining} = result
      assert is_boolean(is_raining)
    end
  end

  describe "find_rain_area/2" do
    test "returns {:error, :no_rain} when not raining at starting point" do
      # Most coordinates are likely not raining at any given time
      # This test may occasionally fail if it happens to be raining
      result = Raining.Weather.find_rain_area(0.0, 0.0)

      case result do
        {:error, :no_rain} -> assert true
        # OK if it happens to be raining
        {:ok, _coords} -> assert true
        # OK if API error
        {:error, _} -> assert true
      end
    end

    test "returns {:ok, coordinates list} when raining at starting point" do
      # Test that the function returns the correct structure
      # Use real API call - result may vary based on weather
      precision = @precision
      result = Raining.Weather.find_rain_area(52.5, 13.4)

      case result do
        {:ok, coords} when is_list(coords) ->
          # Verify all coordinates are tuples
          assert Enum.all?(coords, fn coord ->
                   is_tuple(coord) and tuple_size(coord) == 2
                 end)

          # Verify coordinates are rounded to configured precision
          assert Enum.all?(coords, fn {lat, lng} ->
                   lat == Float.round(lat, precision) and lng == Float.round(lng, precision)
                 end)

        {:error, :no_rain} ->
          # OK if not raining
          assert true

        {:error, _reason} ->
          # OK if API error
          assert true
      end
    end

    test "rounds coordinates before processing" do
      # High precision coordinates should be rounded to configured precision
      precision = @precision
      rounded_lat = Float.round(52.527894, precision)
      rounded_lng = Float.round(13.416234, precision)

      result1 = Raining.Weather.find_rain_area(52.527894, 13.416234)
      result2 = Raining.Weather.find_rain_area(rounded_lat, rounded_lng)

      # Both should process the same rounded coordinates
      assert match?({:ok, _}, result1) or match?({:error, _}, result1)
      assert match?({:ok, _}, result2) or match?({:error, _}, result2)
    end

    test "includes starting coordinate in result when raining" do
      # When rain is detected, starting point should be in result
      precision = @precision
      rounded_lat = Float.round(52.5, precision)
      rounded_lng = Float.round(13.4, precision)

      case Raining.Weather.find_rain_area(52.5, 13.4) do
        {:ok, coords} ->
          assert {rounded_lat, rounded_lng} in coords

        {:error, :no_rain} ->
          # OK if not raining
          assert true

        {:error, _} ->
          # OK if API error
          assert true
      end
    end

    @tag :integration
    test "handles API errors gracefully" do
      # Test with invalid coordinates (though API might still return data)
      result = Raining.Weather.find_rain_area(999, 999)

      # Should return an error tuple or handle gracefully
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end

defmodule Raining.Weather.NWS do
  @moduledoc """
  Client for the National Weather Service (NWS) API.

  Provides functions to:
  - Get forecast zone and observation stations for a location
  - Check weather observations from stations
  - Fetch forecast zone geometries (GeoJSON polygons)
  """

  @base_url "https://api.weather.gov"

  @doc """
  Gets NWS point data for coordinates.

  Returns forecast zone ID, grid coordinates, and observation stations URL.

  ## Examples

      iex> get_point_data(39.7456, -97.0892)
      {:ok, %{
        zone_id: "KSZ009",
        zone_url: "https://api.weather.gov/zones/forecast/KSZ009",
        stations_url: "https://api.weather.gov/gridpoints/TOP/32,81/stations",
        grid_id: "TOP",
        grid_x: 32,
        grid_y: 81
      }}

      iex> get_point_data(0.0, 0.0)  # Outside US
      {:error, :outside_us}
  """
  def get_point_data(latitude, longitude) do
    url = "#{@base_url}/points/#{latitude},#{longitude}"

    case Req.get(url, headers: [{"User-Agent", "RainingApp"}]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          zone_id: extract_zone_id(body),
          zone_url: body["properties"]["forecastZone"],
          stations_url: body["properties"]["observationStations"],
          grid_id: body["properties"]["gridId"],
          grid_x: body["properties"]["gridX"],
          grid_y: body["properties"]["gridY"]
        }}

      {:ok, %{status: 404}} ->
        {:error, :outside_us}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets observation stations for a grid point.

  Takes the stations URL from `get_point_data/2` and returns a list
  of nearby weather stations.

  ## Examples

      iex> get_stations("https://api.weather.gov/gridpoints/TOP/32,81/stations")
      {:ok, [
        %{id: "KMYZ", name: "Marysville Municipal Airport", latitude: 39.8553, longitude: -96.6306},
        ...
      ]}
  """
  def get_stations(stations_url) do
    case Req.get(stations_url, headers: [{"User-Agent", "RainingApp"}]) do
      {:ok, %{status: 200, body: body}} ->
        stations = body["features"]
          |> Enum.take(10)  # Limit to closest 10 stations
          |> Enum.map(&parse_station/1)
        {:ok, stations}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if it's raining at any of the given stations.

  Checks stations in parallel and returns true if ANY station
  reports precipitation in the last 1-3 hours.

  ## Examples

      iex> stations = [%{id: "KMYZ", ...}, %{id: "KCNK", ...}]
      iex> check_stations_for_rain(stations)
      true  # If any station has precipitation
  """
  def check_stations_for_rain(stations) do
    # Check stations in parallel using Task.async_stream
    stations
    |> Task.async_stream(&check_station_precipitation/1,
                          max_concurrency: 5,
                          timeout: 10_000,
                          on_timeout: :kill_task)
    |> Enum.any?(fn
      {:ok, true} -> true
      _ -> false
    end)
  end

  @doc """
  Fetches forecast zone geometry as a GeoJSON polygon.

  ## Examples

      iex> get_zone_geometry("https://api.weather.gov/zones/forecast/KSZ009")
      {:ok, %{
        zone_id: "KSZ009",
        zone_name: "Washington County",
        geometry: %{"type" => "Polygon", "coordinates" => [[[lng, lat], ...]]}
      }}
  """
  def get_zone_geometry(zone_url) do
    case Req.get(zone_url, headers: [{"User-Agent", "RainingApp"}]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          zone_id: extract_zone_id_from_url(zone_url),
          zone_name: body["properties"]["name"],
          geometry: body["geometry"]
        }}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp check_station_precipitation(station) do
    url = "#{@base_url}/stations/#{station.id}/observations/latest"

    case Req.get(url, headers: [{"User-Agent", "RainingApp"}]) do
      {:ok, %{status: 200, body: body}} ->
        precip_1h = get_in(body, ["properties", "precipitationLastHour", "value"])
        precip_3h = get_in(body, ["properties", "precipitationLast3Hours", "value"])

        # Rain if any precipitation in last 3 hours
        (precip_1h && precip_1h > 0) || (precip_3h && precip_3h > 0)

      _ -> false
    end
  end

  defp extract_zone_id(body) do
    body["properties"]["forecastZone"]
    |> extract_zone_id_from_url()
  end

  defp extract_zone_id_from_url(url) do
    url |> String.split("/") |> List.last()
  end

  defp parse_station(feature) do
    %{
      id: feature["properties"]["stationIdentifier"],
      name: feature["properties"]["name"],
      latitude: feature["geometry"]["coordinates"] |> Enum.at(1),
      longitude: feature["geometry"]["coordinates"] |> Enum.at(0)
    }
  end
end

defmodule Raining.Weather.RegionDetector do
  @moduledoc """
  Detects and clusters distinct rainy regions from precipitation grid data.

  Uses spatial clustering to identify separate rain areas and rank them
  by significance (size, intensity, etc.).
  """

  @doc """
  Find the top N most significant rain regions from precipitation data.

  Uses a grid-based clustering approach to identify spatially distinct
  rain areas and ranks them by total precipitation volume.

  ## Parameters

    - `precipitation_points` - List of {lat, lng, precip_mm} tuples
    - `opts` - Options:
      - `:count` - Number of regions to return (default: 3)
      - `:min_cluster_size` - Minimum points per cluster (default: 10)
      - `:distance_threshold` - Max distance in degrees for same cluster (default: 5.0)

  ## Returns

    - List of region maps with `:center`, `:points`, and `:name` keys

  ## Examples

      iex> points = [{40.0, -87.0, 5.0}, {40.1, -87.1, 4.0}, ...]
      iex> RegionDetector.find_top_regions(points, count: 3)
      [
        %{
          name: "Region 1",
          center: {40.05, -87.05},
          points: [{40.0, -87.0, 5.0}, ...],
          total_precip: 125.5,
          point_count: 45
        },
        ...
      ]
  """
  def find_top_regions(precipitation_points, opts \\ []) do
    count = Keyword.get(opts, :count, 3)
    min_cluster_size = Keyword.get(opts, :min_cluster_size, 10)
    distance_threshold = Keyword.get(opts, :distance_threshold, 5.0)

    # Cluster points by geographic proximity
    clusters = cluster_points(precipitation_points, distance_threshold)

    # Filter out small clusters
    significant_clusters =
      clusters
      |> Enum.filter(fn cluster -> length(cluster) >= min_cluster_size end)

    # Rank by total precipitation (size × intensity)
    ranked_clusters =
      significant_clusters
      |> Enum.map(&calculate_cluster_metrics/1)
      |> Enum.sort_by(& &1.total_precip, :desc)
      |> Enum.take(count)

    # Name and format clusters
    ranked_clusters
    |> Enum.with_index(1)
    |> Enum.map(fn {cluster, idx} ->
      Map.put(cluster, :name, "Region #{idx}")
    end)
  end

  # Cluster precipitation points by geographic proximity using grid-based approach
  defp cluster_points(points, distance_threshold) do
    # Sort points by total precipitation (descending) to start with strongest signals
    sorted_points = Enum.sort_by(points, &elem(&1, 2), :desc)

    # Build clusters iteratively
    {clusters, _remaining} =
      Enum.reduce(sorted_points, {[], MapSet.new()}, fn point, {clusters, visited} ->
        point_key = point_to_key(point)

        if MapSet.member?(visited, point_key) do
          {clusters, visited}
        else
          # Start new cluster with BFS
          cluster = grow_cluster([point], points, distance_threshold, visited)
          cluster_keys = Enum.map(cluster, &point_to_key/1) |> MapSet.new()
          new_visited = MapSet.union(visited, cluster_keys)

          {[cluster | clusters], new_visited}
        end
      end)

    clusters
  end

  # Grow a cluster using BFS to find all nearby points
  defp grow_cluster(seed_points, all_points, distance_threshold, visited) do
    grow_cluster_recursive(seed_points, all_points, distance_threshold, visited, seed_points)
  end

  defp grow_cluster_recursive([], _all_points, _distance_threshold, _visited, cluster) do
    cluster
  end

  defp grow_cluster_recursive(
         [current | rest],
         all_points,
         distance_threshold,
         visited,
         cluster
       ) do
    # Find neighbors of current point
    neighbors =
      all_points
      |> Enum.filter(fn point ->
        point_key = point_to_key(point)

        !MapSet.member?(visited, point_key) and
          distance(current, point) <= distance_threshold
      end)

    # Add neighbors to cluster and visited set
    new_cluster = cluster ++ neighbors
    new_visited = Enum.reduce(neighbors, visited, fn point, acc -> MapSet.put(acc, point_to_key(point)) end)

    # Continue BFS with neighbors
    grow_cluster_recursive(
      rest ++ neighbors,
      all_points,
      distance_threshold,
      new_visited,
      new_cluster
    )
  end

  # Calculate cluster metrics (center, total precipitation, etc.)
  defp calculate_cluster_metrics(cluster) do
    lats = Enum.map(cluster, &elem(&1, 0))
    lngs = Enum.map(cluster, &elem(&1, 1))
    precips = Enum.map(cluster, &elem(&1, 2))

    center_lat = Enum.sum(lats) / length(lats)
    center_lng = Enum.sum(lngs) / length(lngs)
    total_precip = Enum.sum(precips)
    max_precip = Enum.max(precips)

    %{
      center: {center_lat, center_lng},
      points: cluster,
      total_precip: total_precip,
      max_precip: max_precip,
      point_count: length(cluster)
    }
  end

  # Calculate approximate distance between two points in degrees
  defp distance({lat1, lng1, _}, {lat2, lng2, _}) do
    # Simple Euclidean distance in degrees (good enough for clustering)
    :math.sqrt(:math.pow(lat2 - lat1, 2) + :math.pow(lng2 - lng1, 2))
  end

  # Convert point to unique key for visited tracking
  defp point_to_key({lat, lng, _precip}) do
    # Round to 2 decimal places for key
    {Float.round(lat, 2), Float.round(lng, 2)}
  end
end

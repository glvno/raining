import type { GeoJSONGeometry } from '../types';

/**
 * Check if a point (lat, lng) is inside a GeoJSON polygon
 * Uses ray-casting algorithm
 */
export function isPointInPolygon(
  lat: number,
  lng: number,
  polygon: GeoJSONGeometry
): boolean {
  if (polygon.type !== 'Polygon') {
    return false;
  }

  // Get the outer ring coordinates (first array in coordinates)
  const ring = polygon.coordinates[0];

  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i];
    const [xj, yj] = ring[j];

    // Check if point is inside using ray-casting algorithm
    const intersect =
      yi > lat !== yj > lat &&
      lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi;

    if (intersect) {
      inside = !inside;
    }
  }

  return inside;
}

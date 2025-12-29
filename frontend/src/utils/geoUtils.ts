import type { GeoJSONGeometry } from '../types';

// Polygon coordinates: array of rings, each ring is array of [lng, lat] pairs
type PolygonCoordinates = [number, number][][];

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
  // Cast to polygon coordinates since we've verified the type
  const ring = (polygon.coordinates as PolygonCoordinates)[0];

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

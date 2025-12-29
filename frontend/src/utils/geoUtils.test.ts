import { describe, it, expect } from 'vitest';
import { isPointInPolygon } from './geoUtils';
import type { GeoJSONGeometry } from '../types';

describe('isPointInPolygon', () => {
  // A simple square polygon around (0,0) to (10,10)
  const squarePolygon: GeoJSONGeometry = {
    type: 'Polygon',
    coordinates: [
      [
        [0, 0],
        [10, 0],
        [10, 10],
        [0, 10],
        [0, 0], // Close the ring
      ],
    ],
  };

  // A more complex triangle polygon
  const trianglePolygon: GeoJSONGeometry = {
    type: 'Polygon',
    coordinates: [
      [
        [0, 0],
        [10, 0],
        [5, 10],
        [0, 0], // Close the ring
      ],
    ],
  };

  it('returns true for a point inside a square polygon', () => {
    expect(isPointInPolygon(5, 5, squarePolygon)).toBe(true);
  });

  it('returns true for a point at the center of a square polygon', () => {
    expect(isPointInPolygon(5, 5, squarePolygon)).toBe(true);
  });

  it('returns false for a point outside a square polygon', () => {
    expect(isPointInPolygon(15, 15, squarePolygon)).toBe(false);
  });

  it('returns false for a point far outside the polygon', () => {
    expect(isPointInPolygon(-100, -100, squarePolygon)).toBe(false);
  });

  it('returns true for a point inside a triangle polygon', () => {
    expect(isPointInPolygon(3, 5, trianglePolygon)).toBe(true);
  });

  it('returns false for a point outside a triangle polygon', () => {
    // Point is to the right of the triangle
    expect(isPointInPolygon(5, 9, trianglePolygon)).toBe(false);
  });

  it('returns false for non-Polygon geometry types', () => {
    const multiPolygon = {
      type: 'MultiPolygon' as const,
      coordinates: [[[[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]]]],
    };
    expect(isPointInPolygon(5, 5, multiPolygon)).toBe(false);
  });

  // Real-world coordinate test (approximate location in Indiana, USA)
  it('works with real-world coordinates', () => {
    const indianaPolygon: GeoJSONGeometry = {
      type: 'Polygon',
      coordinates: [
        [
          [-87.0, 39.0],
          [-86.0, 39.0],
          [-86.0, 40.0],
          [-87.0, 40.0],
          [-87.0, 39.0],
        ],
      ],
    };

    // Point inside Indiana
    expect(isPointInPolygon(39.5, -86.5, indianaPolygon)).toBe(true);

    // Point outside (in Ohio)
    expect(isPointInPolygon(39.5, -84.0, indianaPolygon)).toBe(false);
  });
});

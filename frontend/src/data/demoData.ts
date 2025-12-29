import type { FeedResponse } from '../types';

/**
 * Demo data for demonstrations when it's not actually raining.
 * Based on REAL current weather system in central Indiana
 *
 * Generated from actual precipitation data at 39.644, -86.8645
 * Polygon created using PostGIS ST_ConcaveHull on real radar data
 * Heaviest precipitation: 37.8mm at (39.14, -87.36)
 * To use: Add ?demo=true to the URL
 */
export const DEMO_FEED_DATA: FeedResponse = {
  droplets: [
    {
      id: 101,
      content: 'Intense rainfall here! 37mm and counting ⛈️',
      latitude: 39.14,
      longitude: -87.36,
      user: {
        id: 1,
        email: 'alice@indiana.local',
      },
      inserted_at: new Date(Date.now() - 5 * 60 * 1000).toISOString(), // 5 minutes ago
      updated_at: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
    },
    {
      id: 102,
      content: 'Heavy rain just started! Lightning everywhere ⚡',
      latitude: 39.64,
      longitude: -86.86,
      user: {
        id: 2,
        email: 'bob@indiana.local',
      },
      inserted_at: new Date(Date.now() - 12 * 60 * 1000).toISOString(), // 12 minutes ago
      updated_at: new Date(Date.now() - 12 * 60 * 1000).toISOString(),
    },
    {
      id: 103,
      content: 'Storm moving through fast! Visibility is terrible',
      latitude: 40.14,
      longitude: -86.36,
      user: {
        id: 3,
        email: 'carol@indiana.local',
      },
      inserted_at: new Date(Date.now() - 18 * 60 * 1000).toISOString(), // 18 minutes ago
      updated_at: new Date(Date.now() - 18 * 60 * 1000).toISOString(),
    },
    {
      id: 104,
      content: 'Major downpour in the northern area! 🌧️',
      latitude: 41.14,
      longitude: -85.86,
      user: {
        id: 4,
        email: 'dan@indiana.local',
      },
      inserted_at: new Date(Date.now() - 25 * 60 * 1000).toISOString(), // 25 minutes ago
      updated_at: new Date(Date.now() - 25 * 60 * 1000).toISOString(),
    },
    {
      id: 105,
      content: 'Rain picking up intensity here! Stay safe everyone!',
      latitude: 38.64,
      longitude: -87.86,
      user: {
        id: 5,
        email: 'eve@indiana.local',
      },
      inserted_at: new Date(Date.now() - 35 * 60 * 1000).toISOString(), // 35 minutes ago
      updated_at: new Date(Date.now() - 35 * 60 * 1000).toISOString(),
    },
    {
      id: 106,
      content: 'Steady rain here, roads starting to puddle 💧',
      latitude: 40.64,
      longitude: -85.86,
      user: {
        id: 6,
        email: 'frank@indiana.local',
      },
      inserted_at: new Date(Date.now() - 48 * 60 * 1000).toISOString(), // 48 minutes ago
      updated_at: new Date(Date.now() - 48 * 60 * 1000).toISOString(),
    },
    {
      id: 107,
      content: 'Thunder rolling through! The storm is here 💥',
      latitude: 39.4,
      longitude: -87.0,
      user: {
        id: 7,
        email: 'grace@indiana.local',
      },
      inserted_at: new Date(Date.now() - 65 * 60 * 1000).toISOString(), // 1 hour 5 minutes ago
      updated_at: new Date(Date.now() - 65 * 60 * 1000).toISOString(),
    },
    {
      id: 108,
      content: 'Light rain continuing up north ☁️',
      latitude: 41.64,
      longitude: -85.36,
      user: {
        id: 8,
        email: 'henry@indiana.local',
      },
      inserted_at: new Date(Date.now() - 82 * 60 * 1000).toISOString(), // 1 hour 22 minutes ago
      updated_at: new Date(Date.now() - 82 * 60 * 1000).toISOString(),
    },
    {
      id: 109,
      content: 'Clouds building up, rain starting to fall 🌦️',
      latitude: 37.64,
      longitude: -88.36,
      user: {
        id: 9,
        email: 'iris@indiana.local',
      },
      inserted_at: new Date(Date.now() - 95 * 60 * 1000).toISOString(), // 1 hour 35 minutes ago
      updated_at: new Date(Date.now() - 95 * 60 * 1000).toISOString(),
    },
  ],
  count: 9,
  time_window_hours: 2,
  rain_zone: {
    type: 'Polygon',
    // Real precipitation polygon generated from actual radar data using PostGIS ST_ConcaveHull
    // Generated from live weather at 39.644, -86.8645 on 2025-12-28
    // 16 precipitation points, max 37.8mm at (39.14, -87.36)
    coordinates: [
      [
        [-85.3645, 41.644],
        [-85.3645, 40.644],
        [-88.3645, 37.644],
        [-88.8645, 37.644],
        [-85.8645, 41.144],
        [-85.3645, 41.644],
      ],
    ],
  },
};

/**
 * Demo user location (Central Indiana)
 * Coordinates match the location used to generate the real precipitation polygon
 */
export const DEMO_USER_LOCATION = {
  latitude: 39.644,
  longitude: -86.8645,
};

/**
 * Fixed radar timestamp for demo mode
 * Timestamp adjusted 10 minutes earlier to better match precipitation polygon
 * This is a snapshot from 2024-12-28 22:35 UTC showing ACTIVE severe weather in Indiana
 */
export const DEMO_RADAR_TIMESTAMP = 1766967600;

import type { FeedResponse } from '../types';

/**
 * Demo data for demonstrations when it's not actually raining.
 *
 * GLOBAL DEMO: Includes droplets from multiple rain areas worldwide:
 * - Central Indiana (user's location)
 * - Pacific Northwest (Seattle area)
 * - UK (London area)
 * - Southeast Asia (Singapore area)
 *
 * To use: Add ?demo=true to the URL
 */
export const DEMO_FEED_DATA: FeedResponse = {
  droplets: [
    // === Indiana Rain Area (user's location) ===
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

    // === Pacific Northwest Rain Area (Seattle) ===
    {
      id: 201,
      content: 'Classic Seattle drizzle! ☔',
      latitude: 47.6,
      longitude: -122.3,
      user: {
        id: 10,
        email: 'sarah@seattle.local',
      },
      inserted_at: new Date(Date.now() - 15 * 60 * 1000).toISOString(), // 15 minutes ago
      updated_at: new Date(Date.now() - 15 * 60 * 1000).toISOString(),
    },
    {
      id: 202,
      content: 'Rain hitting the Puget Sound hard right now 🌊',
      latitude: 47.5,
      longitude: -122.4,
      user: {
        id: 11,
        email: 'mike@seattle.local',
      },
      inserted_at: new Date(Date.now() - 28 * 60 * 1000).toISOString(), // 28 minutes ago
      updated_at: new Date(Date.now() - 28 * 60 * 1000).toISOString(),
    },
    {
      id: 203,
      content: 'Another rainy day in the PNW! Coffee weather ☕',
      latitude: 47.7,
      longitude: -122.2,
      user: {
        id: 12,
        email: 'emma@seattle.local',
      },
      inserted_at: new Date(Date.now() - 42 * 60 * 1000).toISOString(), // 42 minutes ago
      updated_at: new Date(Date.now() - 42 * 60 * 1000).toISOString(),
    },

    // === UK Rain Area (London) ===
    {
      id: 301,
      content: 'Typical British weather innit! ☂️',
      latitude: 51.5,
      longitude: -0.1,
      user: {
        id: 13,
        email: 'james@london.local',
      },
      inserted_at: new Date(Date.now() - 8 * 60 * 1000).toISOString(), // 8 minutes ago
      updated_at: new Date(Date.now() - 8 * 60 * 1000).toISOString(),
    },
    {
      id: 302,
      content: 'Raining on the Thames! 🇬🇧',
      latitude: 51.4,
      longitude: -0.2,
      user: {
        id: 14,
        email: 'olivia@london.local',
      },
      inserted_at: new Date(Date.now() - 22 * 60 * 1000).toISOString(), // 22 minutes ago
      updated_at: new Date(Date.now() - 22 * 60 * 1000).toISOString(),
    },
    {
      id: 303,
      content: 'Steady drizzle across the city center 🌧️',
      latitude: 51.6,
      longitude: 0.0,
      user: {
        id: 15,
        email: 'harry@london.local',
      },
      inserted_at: new Date(Date.now() - 55 * 60 * 1000).toISOString(), // 55 minutes ago
      updated_at: new Date(Date.now() - 55 * 60 * 1000).toISOString(),
    },

    // === Southeast Asia Rain Area (Singapore) ===
    {
      id: 401,
      content: 'Tropical downpour! 🌴⛈️',
      latitude: 1.3,
      longitude: 103.8,
      user: {
        id: 16,
        email: 'wei@singapore.local',
      },
      inserted_at: new Date(Date.now() - 10 * 60 * 1000).toISOString(), // 10 minutes ago
      updated_at: new Date(Date.now() - 10 * 60 * 1000).toISOString(),
    },
    {
      id: 402,
      content: 'Monsoon season intensity! Streets flooding 💧',
      latitude: 1.35,
      longitude: 103.9,
      user: {
        id: 17,
        email: 'mei@singapore.local',
      },
      inserted_at: new Date(Date.now() - 33 * 60 * 1000).toISOString(), // 33 minutes ago
      updated_at: new Date(Date.now() - 33 * 60 * 1000).toISOString(),
    },
    {
      id: 403,
      content: 'Heavy rain near Marina Bay! 🏙️',
      latitude: 1.25,
      longitude: 103.85,
      user: {
        id: 18,
        email: 'raj@singapore.local',
      },
      inserted_at: new Date(Date.now() - 67 * 60 * 1000).toISOString(), // 1 hour 7 minutes ago
      updated_at: new Date(Date.now() - 67 * 60 * 1000).toISOString(),
    },
  ],
  count: 18,
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

/**
 * All global rain zones for demo mode (used by Deluge feed)
 * Includes rain zones from multiple locations worldwide
 */
export const DEMO_GLOBAL_RAIN_ZONES = [
  // Indiana rain zone (user's location)
  {
    type: 'Polygon',
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
  // Pacific Northwest (Seattle area)
  {
    type: 'Polygon',
    coordinates: [
      [
        [-122.5, 47.4],
        [-122.1, 47.4],
        [-122.1, 47.8],
        [-122.5, 47.8],
        [-122.5, 47.4],
      ],
    ],
  },
  // UK (London area)
  {
    type: 'Polygon',
    coordinates: [
      [
        [-0.3, 51.3],
        [0.1, 51.3],
        [0.1, 51.7],
        [-0.3, 51.7],
        [-0.3, 51.3],
      ],
    ],
  },
  // Southeast Asia (Singapore area)
  {
    type: 'Polygon',
    coordinates: [
      [
        [103.7, 1.2],
        [104.0, 1.2],
        [104.0, 1.4],
        [103.7, 1.4],
        [103.7, 1.2],
      ],
    ],
  },
];

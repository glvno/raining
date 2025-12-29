import type { FeedResponse } from '../types';

/**
 * Demo data for demonstrations when it's not actually raining.
 * Based on Jasper County, Indiana with ACTIVE severe weather
 *
 * Radar timestamp: 1766961000 (captured 2024-12-28 22:45 UTC)
 * Location: Rensselaer, IN area - tornado warning with thunderstorms
 * To use: Add ?demo=true to the URL
 */
export const DEMO_FEED_DATA: FeedResponse = {
  droplets: [
    {
      id: 101,
      content: "Tornado warning! Everyone take shelter NOW! ⛈️🌪️",
      latitude: 40.95,
      longitude: -87.05,
      user: {
        id: 1,
        email: "alice@jasper.in"
      },
      inserted_at: new Date(Date.now() - 5 * 60 * 1000).toISOString(), // 5 minutes ago
      updated_at: new Date(Date.now() - 5 * 60 * 1000).toISOString()
    },
    {
      id: 102,
      content: "Severe thunderstorm passing through! Heavy rain and lightning ⚡",
      latitude: 40.92,
      longitude: -87.00,
      user: {
        id: 2,
        email: "bob@jasper.in"
      },
      inserted_at: new Date(Date.now() - 12 * 60 * 1000).toISOString(), // 12 minutes ago
      updated_at: new Date(Date.now() - 12 * 60 * 1000).toISOString()
    },
    {
      id: 103,
      content: "Massive downpour in Rensselaer! Can barely see across the street",
      latitude: 40.94,
      longitude: -87.15,
      user: {
        id: 3,
        email: "carol@jasper.in"
      },
      inserted_at: new Date(Date.now() - 18 * 60 * 1000).toISOString(), // 18 minutes ago
      updated_at: new Date(Date.now() - 18 * 60 * 1000).toISOString()
    },
    {
      id: 104,
      content: "Hail starting to fall! This storm is intense 🧊",
      latitude: 40.98,
      longitude: -87.08,
      user: {
        id: 4,
        email: "dan@jasper.in"
      },
      inserted_at: new Date(Date.now() - 25 * 60 * 1000).toISOString(), // 25 minutes ago
      updated_at: new Date(Date.now() - 25 * 60 * 1000).toISOString()
    },
    {
      id: 105,
      content: "Wind picking up fast, rain coming in sideways! Stay inside folks!",
      latitude: 40.89,
      longitude: -87.12,
      user: {
        id: 5,
        email: "eve@jasper.in"
      },
      inserted_at: new Date(Date.now() - 35 * 60 * 1000).toISOString(), // 35 minutes ago
      updated_at: new Date(Date.now() - 35 * 60 * 1000).toISOString()
    },
    {
      id: 106,
      content: "Flash flooding on the roads near Wolcott. Don't drive through it! 🚧",
      latitude: 40.85,
      longitude: -87.05,
      user: {
        id: 6,
        email: "frank@jasper.in"
      },
      inserted_at: new Date(Date.now() - 48 * 60 * 1000).toISOString(), // 48 minutes ago
      updated_at: new Date(Date.now() - 48 * 60 * 1000).toISOString()
    },
    {
      id: 107,
      content: "Thunder is shaking the whole house! This is wild! 💥",
      latitude: 40.96,
      longitude: -87.02,
      user: {
        id: 7,
        email: "grace@jasper.in"
      },
      inserted_at: new Date(Date.now() - 65 * 60 * 1000).toISOString(), // 1 hour 5 minutes ago
      updated_at: new Date(Date.now() - 65 * 60 * 1000).toISOString()
    },
    {
      id: 108,
      content: "Power just flickered. Storm moving fast through the county ⚡",
      latitude: 40.91,
      longitude: -87.07,
      user: {
        id: 8,
        email: "henry@jasper.in"
      },
      inserted_at: new Date(Date.now() - 82 * 60 * 1000).toISOString(), // 1 hour 22 minutes ago
      updated_at: new Date(Date.now() - 82 * 60 * 1000).toISOString()
    },
    {
      id: 109,
      content: "Dark clouds rolling in from the southwest. Here it comes! ☁️",
      latitude: 40.93,
      longitude: -87.10,
      user: {
        id: 9,
        email: "iris@jasper.in"
      },
      inserted_at: new Date(Date.now() - 95 * 60 * 1000).toISOString(), // 1 hour 35 minutes ago
      updated_at: new Date(Date.now() - 95 * 60 * 1000).toISOString()
    }
  ],
  count: 9,
  time_window_hours: 2,
  rain_zone: {
    type: "Polygon",
    // Real precipitation polygon generated from actual radar data using PostGIS ST_ConcaveHull
    // Generated from current weather data for Indiana area
    coordinates: [[
      [-89.08, 42.44],
      [-89.08, 42.75546921751784],
      [-89.08, 42.94],
      [-88.82246347621307, 42.94],
      [-85.29897345123541, 42.94],
      [-85.08, 42.94],
      [-85.08, 42.73410576602966],
      [-85.08, 40.94],
      [-86.03053339720627, 39.989466602793726],
      [-86.58, 39.44],
      [-87.58, 38.94],
      [-87.9926863509492, 39.90293481888147],
      [-88.78864212690759, 41.76016496278437],
      [-89.08, 42.44]
    ]]
  }
};

/**
 * Demo user location (Rensselaer, IN - Jasper County seat)
 */
export const DEMO_USER_LOCATION = {
  latitude: 40.94,
  longitude: -87.08
};

/**
 * Fixed radar timestamp for demo mode
 * This is a snapshot from 2024-12-28 22:45 UTC showing ACTIVE severe weather in Indiana
 */
export const DEMO_RADAR_TIMESTAMP = 1766961000;

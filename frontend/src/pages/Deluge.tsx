import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { DropletComposer } from '../components/DropletComposer';
import { DropletCard } from '../components/DropletCard';
import { RainAreaIndicator } from '../components/RainAreaIndicator';
import { GlobalMap } from '../components/GlobalMap';
import { DEMO_FEED_DATA, DEMO_GLOBAL_RAIN_ZONES } from '../data/demoData';
import type { Droplet, GeoJSONGeometry } from '../types';

const API_BASE = '/api';
const REFRESH_INTERVAL = 30000; // 30 seconds

export default function Deluge() {
  const [searchParams] = useSearchParams();
  const [droplets, setDroplets] = useState<Droplet[]>([]);
  const [rainZones, setRainZones] = useState<GeoJSONGeometry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const { token } = useAuth();
  const { latitude, longitude } = useLocation();

  // Check if demo mode is enabled via URL parameter
  const isDemoMode = searchParams.get('demo') === 'true';

  // Load feed on mount and when auth changes
  useEffect(() => {
    if (token) {
      loadFeed();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, isDemoMode]); // loadFeed is stable

  // Auto-refresh feed every 30 seconds (skip in demo mode)
  useEffect(() => {
    if (!token || isDemoMode) {
      return;
    }

    const interval = setInterval(() => {
      loadFeed();
    }, REFRESH_INTERVAL);

    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, isDemoMode]); // loadFeed is stable

  const loadFeed = async () => {
    if (!token) {
      return;
    }

    // Use demo data if in demo mode
    if (isDemoMode) {
      // Keep droplets hardcoded (as per requirement)
      setDroplets(DEMO_FEED_DATA.droplets);

      // Fetch demo zones from backend API
      try {
        const response = await fetch(`${API_BASE}/demo/zones`);
        if (response.ok) {
          const data = await response.json();
          // Extract rain_zone from each zone object
          const zones = data.zones.map((z: { rain_zone: GeoJSONGeometry }) => z.rain_zone);
          setRainZones(zones);
        } else {
          // Fallback to hardcoded zones if API fails
          console.warn('Failed to fetch demo zones from API, using hardcoded fallback');
          setRainZones(DEMO_GLOBAL_RAIN_ZONES as GeoJSONGeometry[]);
        }
      } catch (err) {
        // Fallback to hardcoded zones if API fails
        console.warn('Error fetching demo zones:', err);
        setRainZones(DEMO_GLOBAL_RAIN_ZONES as GeoJSONGeometry[]);
      }

      setError(null);
      setIsLoading(false);
      return;
    }

    try {
      const response = await fetch(`${API_BASE}/droplets/global-feed`, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to load global feed');
      }

      const data = await response.json();
      setDroplets(data.droplets);
      setRainZones(data.rain_zones || []);
      setError(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to load global feed';
      setError(message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDropletCreated = (newDroplet: Droplet) => {
    // Add new droplet to the top of the feed (optimistic update)
    setDroplets((prev) => [newDroplet, ...prev]);
  };

  if (isLoading) {
    return (
      <div className="min-h-full bg-gray-50 flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="text-4xl animate-pulse">🌧️</div>
          <p className="text-gray-600">Loading global feed...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-full bg-gray-50">
      <div className="max-w-2xl mx-auto px-4 py-8">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">🌊 Deluge</h1>
          <RainAreaIndicator dropletCount={droplets.length} />
        </div>

        {isDemoMode && (
          <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex items-center gap-2">
              <span className="text-blue-800 font-semibold">🎭 Demo Mode</span>
              <span className="text-sm text-blue-600">
                Showing global rain activity: Indiana 🇺🇸 • Seattle 🌲 • Singapore 🌴
              </span>
            </div>
          </div>
        )}

        <div className="mb-6">
          <GlobalMap
            rainZones={rainZones}
            userLocation={latitude && longitude ? { latitude, longitude } : null}
            droplets={droplets}
          />
        </div>

        <DropletComposer onDropletCreated={handleDropletCreated} />

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}

        <div className="space-y-4">
          {droplets.length === 0 ? (
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
              <div className="text-4xl mb-4">🌊</div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                No droplets yet
              </h3>
              <p className="text-gray-600">
                Be the first to post from around the world!
              </p>
            </div>
          ) : (
            droplets.map((droplet) => (
              <DropletCard key={droplet.id} droplet={droplet} />
            ))
          )}
        </div>
      </div>
    </div>
  );
}

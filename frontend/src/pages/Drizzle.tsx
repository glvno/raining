import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { DropletComposer } from '../components/DropletComposer';
import { DropletCard } from '../components/DropletCard';
import { RainAreaIndicator } from '../components/RainAreaIndicator';
import { RainAreaMap } from '../components/RainAreaMap';
import type { Droplet, FeedResponse, GeoJSONGeometry } from '../types';

const API_BASE = '/api';
const REFRESH_INTERVAL = 30000; // 30 seconds

export default function Drizzle() {
  const [droplets, setDroplets] = useState<Droplet[]>([]);
  const [rainZone, setRainZone] = useState<GeoJSONGeometry | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const { token } = useAuth();
  const { latitude, longitude } = useLocation();

  // Load feed on mount and when location changes
  useEffect(() => {
    if (latitude && longitude && token) {
      loadFeed();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [latitude, longitude, token]); // loadFeed is stable

  // Auto-refresh feed every 30 seconds
  useEffect(() => {
    if (!latitude || !longitude || !token) {
      return;
    }

    const interval = setInterval(() => {
      loadFeed();
    }, REFRESH_INTERVAL);

    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [latitude, longitude, token]); // loadFeed is stable

  const loadFeed = async () => {
    if (!latitude || !longitude || !token) {
      return;
    }

    try {
      const response = await fetch(
        `${API_BASE}/droplets/feed?latitude=${latitude}&longitude=${longitude}`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      );

      if (!response.ok) {
        throw new Error('Failed to load feed');
      }

      const data: FeedResponse = await response.json();
      setDroplets(data.droplets);
      setRainZone(data.rain_zone);
      setError(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to load feed';
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
          <div className="text-4xl animate-pulse">Loading...</div>
          <p className="text-gray-600">Loading feed...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-full bg-gray-50">
      <div className="max-w-2xl mx-auto px-4 py-8">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Drizzle</h1>
          <RainAreaIndicator dropletCount={droplets.length} />
        </div>

        <div className="mb-6">
          <RainAreaMap
            rainZone={rainZone}
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
              <div className="text-4xl mb-4">💧</div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">No droplets yet</h3>
              <p className="text-gray-600">Be the first to post in your rain area!</p>
            </div>
          ) : (
            droplets.map((droplet) => <DropletCard key={droplet.id} droplet={droplet} />)
          )}
        </div>
      </div>
    </div>
  );
}

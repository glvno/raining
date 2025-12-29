import { createContext, useContext, useState, useEffect } from 'react';
import type { ReactNode } from 'react';
import { useSearchParams } from 'react-router';
import { useAuth } from './AuthContext';
import { DEMO_USER_LOCATION, DEMO_FEED_DATA } from '../data/demoData';
import type { FeedResponse } from '../types';

const LOCATION_KEY = 'raining_location';
const API_BASE = '/api';
const REFRESH_INTERVAL = 30000; // 30 seconds

interface LocationContextType {
  latitude: number | null;
  longitude: number | null;
  isRaining: boolean;
  rainAreaSize: number;
  isLoading: boolean;
  error: string | null;
  refreshRainStatus: () => Promise<void>;
  setManualLocation: (lat: number, lng: number) => void;
}

const LocationContext = createContext<LocationContextType | undefined>(undefined);

export function LocationProvider({ children }: { children: ReactNode }) {
  const { token, isAuthenticated } = useAuth();
  const [searchParams] = useSearchParams();
  const [realLatitude, setRealLatitude] = useState<number | null>(null);
  const [realLongitude, setRealLongitude] = useState<number | null>(null);
  const [isRaining, setIsRaining] = useState(false);
  const [rainAreaSize, setRainAreaSize] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Check if demo mode is enabled - recomputes when URL params change
  const isDemoMode = searchParams.get('demo') === 'true';

  // Use demo location if in demo mode, otherwise use real location
  const latitude = isDemoMode ? DEMO_USER_LOCATION.latitude : realLatitude;
  const longitude = isDemoMode ? DEMO_USER_LOCATION.longitude : realLongitude;

  // Initialize demo mode data
  useEffect(() => {
    if (isDemoMode) {
      setIsRaining(true);
      setRainAreaSize(DEMO_FEED_DATA.count);
      setIsLoading(false);
      console.log('[LocationContext] Demo mode active - using demo data');
    }
  }, [isDemoMode]);

  // Load cached location from localStorage (skip in demo mode)
  useEffect(() => {
    if (isDemoMode) return;

    const cached = localStorage.getItem(LOCATION_KEY);
    if (cached) {
      try {
        const { lat, lng } = JSON.parse(cached);
        setRealLatitude(lat);
        setRealLongitude(lng);
      } catch (err) {
        console.error('Failed to parse cached location:', err);
      }
    }
  }, [isDemoMode]);

  // Request geolocation permission on mount (skip in demo mode)
  useEffect(() => {
    if (isDemoMode) return;

    if (!realLatitude || !realLongitude) {
      requestGeolocation();
    } else {
      setIsLoading(false);
    }
  }, [isDemoMode]);

  // Check rain status when location or auth changes (skip in demo mode)
  useEffect(() => {
    if (isDemoMode) return;

    if (latitude && longitude && isAuthenticated && token) {
      checkRainStatus();
    }
  }, [latitude, longitude, isAuthenticated, token, isDemoMode]);

  // Auto-refresh rain status every 30 seconds (skip in demo mode)
  useEffect(() => {
    if (isDemoMode) return;

    if (!latitude || !longitude || !isAuthenticated || !token) {
      return;
    }

    const interval = setInterval(() => {
      checkRainStatus();
    }, REFRESH_INTERVAL);

    return () => clearInterval(interval);
  }, [latitude, longitude, isAuthenticated, token, isDemoMode]);

  const requestGeolocation = () => {
    setIsLoading(true);
    setError(null);

    if (!navigator.geolocation) {
      setError('Geolocation is not supported by your browser');
      setIsLoading(false);
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;
        setRealLatitude(lat);
        setRealLongitude(lng);
        localStorage.setItem(LOCATION_KEY, JSON.stringify({ lat, lng }));
        setIsLoading(false);
      },
      (err) => {
        setError(`Unable to get location: ${err.message}`);
        setIsLoading(false);
      },
      {
        enableHighAccuracy: false,
        timeout: 10000,
        maximumAge: 300000, // Cache for 5 minutes
      }
    );
  };

  const checkRainStatus = async () => {
    if (!latitude || !longitude || !token) {
      return;
    }

    try {
      const url = `${API_BASE}/droplets/feed?latitude=${latitude}&longitude=${longitude}`;
      console.log('[LocationContext] Checking rain status at:', { latitude, longitude, url });

      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      console.log('[LocationContext] Response status:', response.status);

      if (!response.ok) {
        const errorText = await response.text();
        console.error('[LocationContext] Error response:', errorText);
        throw new Error('Failed to check rain status');
      }

      const data: FeedResponse = await response.json();
      console.log('[LocationContext] Feed response:', data);

      // Rain detected if there's NO message saying "Not raining"
      // Message field only exists when it's not raining
      const raining = !data.message;
      console.log('[LocationContext] Rain detected:', raining, 'Message:', data.message, 'Count:', data.count, 'Droplets:', data.droplets.length);

      setIsRaining(raining);
      setRainAreaSize(data.count || 0);
      setError(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to check rain status';
      console.error('[LocationContext] Error checking rain status:', err);
      setError(message);
      // Don't update rain status on error - keep previous state
    }
  };

  const refreshRainStatus = async () => {
    await checkRainStatus();
  };

  const setManualLocation = (lat: number, lng: number) => {
    // Only allow in development mode and not in demo mode
    if (import.meta.env.DEV && !isDemoMode) {
      setRealLatitude(lat);
      setRealLongitude(lng);
      localStorage.setItem(LOCATION_KEY, JSON.stringify({ lat, lng }));
    } else if (isDemoMode) {
      console.warn('Cannot override location in demo mode');
    } else {
      console.warn('Manual location override is only available in development mode');
    }
  };

  const value: LocationContextType = {
    latitude,
    longitude,
    isRaining,
    rainAreaSize,
    isLoading,
    error,
    refreshRainStatus,
    setManualLocation,
  };

  return <LocationContext.Provider value={value}>{children}</LocationContext.Provider>;
}

export function useLocation() {
  const context = useContext(LocationContext);
  if (context === undefined) {
    throw new Error('useLocation must be used within a LocationProvider');
  }
  return context;
}

import { createContext, useContext, useState, useEffect } from 'react';
import type { ReactNode } from 'react';
import { useAuth } from './AuthContext';
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
  const [latitude, setLatitude] = useState<number | null>(null);
  const [longitude, setLongitude] = useState<number | null>(null);
  const [isRaining, setIsRaining] = useState(false);
  const [rainAreaSize, setRainAreaSize] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load cached location from localStorage
  useEffect(() => {
    const cached = localStorage.getItem(LOCATION_KEY);
    if (cached) {
      try {
        const { lat, lng } = JSON.parse(cached);
        setLatitude(lat);
        setLongitude(lng);
      } catch (err) {
        console.error('Failed to parse cached location:', err);
      }
    }
  }, []);

  // Request geolocation permission on mount
  useEffect(() => {
    if (!latitude || !longitude) {
      requestGeolocation();
    } else {
      setIsLoading(false);
    }
  }, []);

  // Check rain status when location or auth changes
  useEffect(() => {
    if (latitude && longitude && isAuthenticated && token) {
      checkRainStatus();
    }
  }, [latitude, longitude, isAuthenticated, token]);

  // Auto-refresh rain status every 30 seconds
  useEffect(() => {
    if (!latitude || !longitude || !isAuthenticated || !token) {
      return;
    }

    const interval = setInterval(() => {
      checkRainStatus();
    }, REFRESH_INTERVAL);

    return () => clearInterval(interval);
  }, [latitude, longitude, isAuthenticated, token]);

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
        setLatitude(lat);
        setLongitude(lng);
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
      const response = await fetch(
        `${API_BASE}/droplets/feed?latitude=${latitude}&longitude=${longitude}`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        }
      );

      if (!response.ok) {
        throw new Error('Failed to check rain status');
      }

      const data: FeedResponse = await response.json();

      // Rain detected if feed has droplets OR count > 0
      const raining = data.droplets.length > 0 || data.count > 0;
      setIsRaining(raining);
      setRainAreaSize(data.count || 0);
      setError(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to check rain status';
      setError(message);
      // Don't update rain status on error - keep previous state
    }
  };

  const refreshRainStatus = async () => {
    await checkRainStatus();
  };

  const setManualLocation = (lat: number, lng: number) => {
    // Only allow in development mode
    if (import.meta.env.DEV) {
      setLatitude(lat);
      setLongitude(lng);
      localStorage.setItem(LOCATION_KEY, JSON.stringify({ lat, lng }));
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

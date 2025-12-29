import { useState, useEffect, useRef } from 'react';
import { useSearchParams } from 'react-router';
import { useLocation } from '../contexts/LocationContext';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

interface LocationPickerMapProps {
  currentLat: number | null;
  currentLng: number | null;
  onLocationClick: (lat: number, lng: number) => void;
}

function LocationPickerMap({ currentLat, currentLng, onLocationClick }: LocationPickerMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);
  const radarLayerRef = useRef<L.TileLayer | null>(null);
  const [radarTimestamp, setRadarTimestamp] = useState<number | null>(null);

  // Fetch radar timestamp for precipitation overlay
  useEffect(() => {
    const fetchRadarTimestamp = async () => {
      try {
        const response = await fetch('https://api.rainviewer.com/public/weather-maps.json');
        const data = await response.json();
        if (data.radar && data.radar.past && data.radar.past.length > 0) {
          const latest = data.radar.past[data.radar.past.length - 1];
          setRadarTimestamp(latest.time);
        }
      } catch (error) {
        console.error('Failed to fetch radar timestamp:', error);
      }
    };

    fetchRadarTimestamp();
    const interval = setInterval(fetchRadarTimestamp, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  // Initialize map on mount
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const defaultCenter: [number, number] = [currentLat || 40, currentLng || -100];
    const defaultZoom = currentLat && currentLng ? 8 : 3;

    const map = L.map(mapContainerRef.current, {
      center: defaultCenter,
      zoom: defaultZoom,
      scrollWheelZoom: true,
    });

    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      attribution: '&copy; <a href="https://carto.com/">CARTO</a>',
    }).addTo(map);

    // Add click handler
    map.on('click', (e) => {
      const { lat, lng } = e.latlng;
      onLocationClick(lat, lng);
    });

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // Add/update radar layer when timestamp changes
  useEffect(() => {
    if (!mapRef.current || !radarTimestamp) return;

    const map = mapRef.current;

    if (radarLayerRef.current) {
      map.removeLayer(radarLayerRef.current);
    }

    const radarLayer = L.tileLayer(
      `https://tilecache.rainviewer.com/v2/radar/${radarTimestamp}/256/{z}/{x}/{y}/6/1_1.png`,
      {
        opacity: 0.6,
        zIndex: 500,
      }
    ).addTo(map);

    radarLayerRef.current = radarLayer;

    return () => {
      if (radarLayerRef.current) {
        map.removeLayer(radarLayerRef.current);
        radarLayerRef.current = null;
      }
    };
  }, [radarTimestamp]);

  // Update marker when location changes
  useEffect(() => {
    if (!mapRef.current) return;

    // Remove existing marker
    if (markerRef.current) {
      markerRef.current.remove();
      markerRef.current = null;
    }

    // Add new marker if location is set
    if (currentLat && currentLng) {
      const marker = L.marker([currentLat, currentLng]).addTo(mapRef.current);
      marker.bindPopup('Your Location');
      markerRef.current = marker;
    }
  }, [currentLat, currentLng]);

  return (
    <div
      ref={mapContainerRef}
      className="h-48 w-full cursor-crosshair"
      style={{ minHeight: '192px' }}
    />
  );
}

export function DevLocationPanel() {
  const { latitude, longitude, setManualLocation } = useLocation();
  const [searchParams, setSearchParams] = useSearchParams();
  const [isOpen, setIsOpen] = useState(false);
  const [lat, setLat] = useState('');
  const [lng, setLng] = useState('');
  const [isFindingRain, setIsFindingRain] = useState(false);

  // Check if demo mode is enabled - recomputes when URL params change
  const isDemoMode = searchParams.get('demo') === 'true';

  const toggleDemoMode = () => {
    if (isDemoMode) {
      searchParams.delete('demo');
    } else {
      searchParams.set('demo', 'true');
    }
    setSearchParams(searchParams);
  };

  // Update form when current location changes
  useEffect(() => {
    if (latitude !== null && lat === '') {
      setLat(latitude.toString());
    }
    if (longitude !== null && lng === '') {
      setLng(longitude.toString());
    }
  }, [latitude, longitude]);

  // Only show in development
  if (!import.meta.env.DEV) {
    return null;
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    const latNum = parseFloat(lat);
    const lngNum = parseFloat(lng);

    if (isNaN(latNum) || isNaN(lngNum)) {
      alert('Please enter valid numbers for latitude and longitude.');
      return;
    }

    if (latNum < -90 || latNum > 90) {
      alert('Latitude must be between -90 and 90.');
      return;
    }

    if (lngNum < -180 || lngNum > 180) {
      alert('Longitude must be between -180 and 180.');
      return;
    }

    setManualLocation(latNum, lngNum);
    setIsOpen(false);
  };

  const findRainyLocation = async () => {
    setIsFindingRain(true);

    // List of 20 rainiest cities worldwide to check
    const locations = [
      { name: 'Mawsynram, India', lat: 25.3, lng: 91.6 },
      { name: 'Cherrapunji, India', lat: 25.3, lng: 91.7 },
      { name: 'Tutunendo, Colombia', lat: 5.8, lng: -76.5 },
      { name: 'Cropp River, New Zealand', lat: -43.7, lng: 169.8 },
      { name: 'San Antonio de Ureca, Equatorial Guinea', lat: 1.5, lng: 8.8 },
      { name: 'Debundscha, Cameroon', lat: 4.0, lng: 9.0 },
      { name: 'Quibdó, Colombia', lat: 5.7, lng: -76.7 },
      { name: 'Singapore', lat: 1.3, lng: 103.8 },
      { name: 'Kuala Lumpur, Malaysia', lat: 3.1, lng: 101.7 },
      { name: 'Mumbai, India', lat: 19.1, lng: 72.9 },
      { name: 'Bergen, Norway', lat: 60.4, lng: 5.3 },
      { name: 'Vancouver, BC', lat: 49.3, lng: -123.1 },
      { name: 'Seattle, WA', lat: 47.6, lng: -122.3 },
      { name: 'Portland, OR', lat: 45.5, lng: -122.7 },
      { name: 'London, UK', lat: 51.5, lng: -0.1 },
      { name: 'Dublin, Ireland', lat: 53.3, lng: -6.3 },
      { name: 'Glasgow, Scotland', lat: 55.9, lng: -4.3 },
      { name: 'Hilo, Hawaii', lat: 19.7, lng: -155.1 },
      { name: 'Monrovia, Liberia', lat: 6.3, lng: -10.8 },
      { name: 'Conakry, Guinea', lat: 9.6, lng: -13.6 },
    ];

    try {
      // Check each location using backend weather API
      for (const loc of locations) {
        const response = await fetch(
          `/api/weather/check?latitude=${loc.lat}&longitude=${loc.lng}`,
          {
            headers: {
              'Authorization': `Bearer ${localStorage.getItem('raining_auth_token')}`
            }
          }
        );

        if (!response.ok) continue;

        const data = await response.json();

        if (data.is_raining) {
          // Use the rounded coordinates from backend
          setLat(data.rounded_latitude.toString());
          setLng(data.rounded_longitude.toString());
          alert(`Found rain near ${loc.name}!\nRounded coords: (${data.rounded_latitude}, ${data.rounded_longitude})`);
          setIsFindingRain(false);
          return;
        }
      }

      // If no rain found in any location, just use Seattle as fallback
      alert('No rain detected in common locations. Using Seattle as fallback.');
      setLat('47.6');
      setLng('-122.3');
    } catch (error) {
      console.error('Error finding rainy location:', error);
      alert('Error finding rainy location. Using Seattle as fallback.');
      setLat('47.6');
      setLng('-122.3');
    } finally {
      setIsFindingRain(false);
    }
  };

  const handleMapClick = (lat: number, lng: number) => {
    setManualLocation(lat, lng);
    setIsOpen(false); // Close panel after setting location
  };

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-4 right-4 bg-purple-600 text-white px-4 py-2 rounded-lg shadow-lg hover:bg-purple-700 transition-colors text-sm font-medium z-50"
      >
        📍 Dev Location
      </button>
    );
  }

  return (
    <div className="fixed bottom-4 right-4 bg-white border-2 border-purple-600 rounded-lg shadow-xl p-4 w-80 z-50">
      <div className="flex justify-between items-center mb-3">
        <h3 className="font-bold text-purple-900">Override Location (Dev)</h3>
        <button
          onClick={() => setIsOpen(false)}
          className="text-gray-500 hover:text-gray-700"
        >
          ✕
        </button>
      </div>

      <button
        onClick={toggleDemoMode}
        className={`w-full mb-3 px-4 py-3 rounded-lg border-2 font-medium transition-all ${
          isDemoMode
            ? 'bg-blue-50 border-blue-400 text-blue-900 hover:bg-blue-100'
            : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50'
        }`}
      >
        <div className="flex items-center justify-between">
          <span className="flex items-center gap-2">
            <span className="text-lg">{isDemoMode ? '🎭' : '🌍'}</span>
            <span className="text-sm font-semibold">
              {isDemoMode ? 'Demo Mode: ON' : 'Demo Mode: OFF'}
            </span>
          </span>
          <span className="text-xs bg-white px-2 py-1 rounded border border-gray-200">
            {isDemoMode ? 'Click to disable' : 'Click to enable'}
          </span>
        </div>
        {isDemoMode && (
          <div className="mt-2 text-xs text-blue-700">
            Jasper County, IN • Active severe weather • Real radar
          </div>
        )}
      </button>

      <div className="mb-3 text-sm bg-purple-50 p-2 rounded">
        <p className="font-medium text-purple-900">Current Location:</p>
        <p className="text-purple-700 font-mono text-xs">
          {latitude?.toFixed(4) ?? 'N/A'}, {longitude?.toFixed(4) ?? 'N/A'}
        </p>
      </div>

      <div className="mb-3 text-xs bg-blue-50 p-2 rounded border border-blue-200">
        <p className="font-medium text-blue-900">Form values:</p>
        <p className="text-blue-700 font-mono">
          Lat: {lat || '(empty)'} | Lng: {lng || '(empty)'}
        </p>
      </div>

      {!isDemoMode && (
        <div className="mb-4">
          <label className="block text-sm font-medium text-purple-700 mb-2">
            Click on map to set location:
          </label>
          <div className="border-2 border-purple-300 rounded-lg overflow-hidden">
            <LocationPickerMap
              currentLat={latitude}
              currentLng={longitude}
              onLocationClick={handleMapClick}
            />
          </div>
          <p className="text-xs text-purple-600 mt-1">
            💡 Click anywhere to set your location
          </p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-2">
        <div>
          <label htmlFor="dev-lat" className="block text-xs font-medium text-gray-700 mb-1">
            Latitude (-90 to 90)
          </label>
          <input
            id="dev-lat"
            type="text"
            inputMode="decimal"
            value={lat}
            onChange={(e) => setLat(e.target.value)}
            placeholder="e.g., 52.5"
            disabled={isDemoMode}
            className="w-full px-3 py-2 border-2 border-gray-300 rounded text-sm focus:border-purple-500 focus:outline-none bg-white text-gray-900 disabled:bg-gray-100 disabled:cursor-not-allowed"
            autoComplete="off"
          />
        </div>

        <div>
          <label htmlFor="dev-lng" className="block text-xs font-medium text-gray-700 mb-1">
            Longitude (-180 to 180)
          </label>
          <input
            id="dev-lng"
            type="text"
            inputMode="decimal"
            value={lng}
            onChange={(e) => setLng(e.target.value)}
            placeholder="e.g., 13.4"
            disabled={isDemoMode}
            className="w-full px-3 py-2 border-2 border-gray-300 rounded text-sm focus:border-purple-500 focus:outline-none bg-white text-gray-900 disabled:bg-gray-100 disabled:cursor-not-allowed"
            autoComplete="off"
          />
        </div>

        <button
          type="submit"
          disabled={isDemoMode}
          className="w-full bg-purple-600 text-white py-2 rounded font-medium hover:bg-purple-700 transition-colors text-sm disabled:bg-gray-400 disabled:cursor-not-allowed"
        >
          Set Location
        </button>
      </form>

      <button
        type="button"
        onClick={findRainyLocation}
        disabled={isFindingRain || isDemoMode}
        className="w-full mt-2 bg-green-600 text-white py-2 rounded font-medium hover:bg-green-700 transition-colors text-sm disabled:bg-gray-400 disabled:cursor-not-allowed"
      >
        {isFindingRain ? '🔍 Finding rain...' : '🌧️ Find Rainy Location'}
      </button>

      <div className="mt-3 pt-3 border-t border-gray-200">
        <p className="text-xs text-gray-600 font-medium mb-1">Quick locations:</p>
        <div className="grid grid-cols-2 gap-1">
          <button
            type="button"
            onClick={() => {
              setManualLocation(52.5, 13.4);
              setIsOpen(false);
            }}
            disabled={isDemoMode}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Berlin
          </button>
          <button
            type="button"
            onClick={() => {
              setManualLocation(51.5, -0.1);
              setIsOpen(false);
            }}
            disabled={isDemoMode}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded disabled:opacity-50 disabled:cursor-not-allowed"
          >
            London
          </button>
          <button
            type="button"
            onClick={() => {
              setManualLocation(47.6, -122.3);
              setIsOpen(false);
            }}
            disabled={isDemoMode}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Seattle
          </button>
          <button
            type="button"
            onClick={() => {
              setManualLocation(40.7, -74.0);
              setIsOpen(false);
            }}
            disabled={isDemoMode}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded disabled:opacity-50 disabled:cursor-not-allowed"
          >
            NYC
          </button>
        </div>
      </div>
    </div>
  );
}

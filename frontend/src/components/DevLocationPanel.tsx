import { useState, useEffect, useRef } from 'react';
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Intentionally only run on mount

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
  const [isOpen, setIsOpen] = useState(false);
  const [lat, setLat] = useState('');
  const [lng, setLng] = useState('');

  // Update form when current location changes (only if form is empty)
  useEffect(() => {
    if (latitude !== null && lat === '') {
      setLat(latitude.toString());
    }
    if (longitude !== null && lng === '') {
      setLng(longitude.toString());
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [latitude, longitude]); // Intentionally exclude lat/lng to only set initial values

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

  const handleMapClick = (clickedLat: number, clickedLng: number) => {
    setManualLocation(clickedLat, clickedLng);
    setIsOpen(false); // Close panel after setting location
  };

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-4 right-4 bg-purple-600 text-white px-4 py-2 rounded-lg shadow-lg hover:bg-purple-700 transition-colors text-sm font-medium z-50"
      >
        Dev Location
      </button>
    );
  }

  return (
    <div className="fixed bottom-4 right-4 bg-white border-2 border-purple-600 rounded-lg shadow-xl p-4 w-80 z-50">
      <div className="flex justify-between items-center mb-3">
        <h3 className="font-bold text-purple-900">Override Location (Dev)</h3>
        <button onClick={() => setIsOpen(false)} className="text-gray-500 hover:text-gray-700">
          X
        </button>
      </div>

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
        <p className="text-xs text-purple-600 mt-1">Click anywhere to set your location</p>
      </div>

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
            className="w-full px-3 py-2 border-2 border-gray-300 rounded text-sm focus:border-purple-500 focus:outline-none bg-white text-gray-900"
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
            className="w-full px-3 py-2 border-2 border-gray-300 rounded text-sm focus:border-purple-500 focus:outline-none bg-white text-gray-900"
            autoComplete="off"
          />
        </div>

        <button
          type="submit"
          className="w-full bg-purple-600 text-white py-2 rounded font-medium hover:bg-purple-700 transition-colors text-sm"
        >
          Set Location
        </button>
      </form>
    </div>
  );
}

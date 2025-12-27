import { useState, useEffect } from 'react';
import { useLocation } from '../contexts/LocationContext';

export function DevLocationPanel() {
  const { latitude, longitude, setManualLocation } = useLocation();
  const [isOpen, setIsOpen] = useState(false);
  const [lat, setLat] = useState(latitude?.toString() ?? '');
  const [lng, setLng] = useState(longitude?.toString() ?? '');

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

      <div className="mt-3 pt-3 border-t border-gray-200">
        <p className="text-xs text-gray-600 font-medium mb-1">Quick locations:</p>
        <div className="grid grid-cols-2 gap-1">
          <button
            type="button"
            onClick={() => {
              setManualLocation(52.5, 13.4);
              setIsOpen(false);
            }}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded"
          >
            Berlin
          </button>
          <button
            type="button"
            onClick={() => {
              setManualLocation(51.5, -0.1);
              setIsOpen(false);
            }}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded"
          >
            London
          </button>
          <button
            type="button"
            onClick={() => {
              setManualLocation(47.6, -122.3);
              setIsOpen(false);
            }}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded"
          >
            Seattle
          </button>
          <button
            type="button"
            onClick={() => {
              setManualLocation(40.7, -74.0);
              setIsOpen(false);
            }}
            className="text-xs bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded"
          >
            NYC
          </button>
        </div>
      </div>
    </div>
  );
}

import { useEffect, useRef } from 'react';
import L from 'leaflet';
import type { GeoJSONGeometry, Droplet } from '../types';

interface RainAreaMapProps {
  rainZone: GeoJSONGeometry | null;
  userLocation: { latitude: number; longitude: number } | null;
  droplets: Droplet[];
}

export function RainAreaMap({ rainZone, userLocation, droplets }: RainAreaMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const layersRef = useRef<{
    zoneLayer: L.GeoJSON | null;
    userMarker: L.Marker | null;
    dropletMarkers: L.Marker[];
  }>({
    zoneLayer: null,
    userMarker: null,
    dropletMarkers: [],
  });

  // Initialize map on mount
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [0, 0],
      zoom: 2,
      scrollWheelZoom: false,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19,
    }).addTo(map);

    mapRef.current = map;

    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  // Update layers when data changes
  useEffect(() => {
    if (!mapRef.current) return;

    const map = mapRef.current;
    const layers = layersRef.current;

    // Clear existing layers
    if (layers.zoneLayer) {
      map.removeLayer(layers.zoneLayer);
      layers.zoneLayer = null;
    }
    if (layers.userMarker) {
      map.removeLayer(layers.userMarker);
      layers.userMarker = null;
    }
    layers.dropletMarkers.forEach((marker) => map.removeLayer(marker));
    layers.dropletMarkers = [];

    const bounds = L.latLngBounds([]);
    let hasContent = false;

    // Add rain zone polygon
    if (rainZone) {
      const zoneLayer = L.geoJSON(rainZone as any, {
        style: {
          color: '#3b82f6',
          weight: 2,
          opacity: 0.7,
          fillColor: '#3b82f6',
          fillOpacity: 0.1,
        },
      }).addTo(map);

      layers.zoneLayer = zoneLayer;
      bounds.extend(zoneLayer.getBounds());
      hasContent = true;
    }

    // Add user location marker (red circle)
    if (userLocation) {
      const userIcon = L.divIcon({
        html: '<div style="background: #ef4444; width: 16px; height: 16px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>',
        className: 'user-location-marker',
        iconSize: [16, 16],
        iconAnchor: [8, 8],
      });

      const marker = L.marker([userLocation.latitude, userLocation.longitude], {
        icon: userIcon,
        title: 'Your location',
      }).addTo(map);

      layers.userMarker = marker;
      bounds.extend(marker.getLatLng());
      hasContent = true;
    }

    // Add droplet markers (blue dots with popups)
    const dropletIcon = L.divIcon({
      html: '<div style="background: #3b82f6; width: 10px; height: 10px; border-radius: 50%; border: 2px solid white; box-shadow: 0 1px 2px rgba(0,0,0,0.3);"></div>',
      className: 'droplet-marker',
      iconSize: [10, 10],
      iconAnchor: [5, 5],
    });

    droplets.forEach((droplet) => {
      const marker = L.marker([droplet.latitude, droplet.longitude], {
        icon: dropletIcon,
        title: droplet.content.substring(0, 50),
      }).addTo(map);

      marker.bindPopup(
        `<div style="min-width: 150px;">
          <p style="font-weight: 600; margin-bottom: 4px;">${droplet.user.email}</p>
          <p style="margin-bottom: 0;">${droplet.content}</p>
        </div>`,
      );

      layers.dropletMarkers.push(marker);
      bounds.extend(marker.getLatLng());
      hasContent = true;
    });

    // Auto-fit map to show all content
    if (hasContent && bounds.isValid()) {
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 13 });
    } else {
      map.setView([0, 0], 2);
    }
  }, [rainZone, userLocation, droplets]);

  return (
    <div className="w-full h-[300px] md:h-[400px] rounded-lg overflow-hidden shadow-sm border border-gray-200">
      <div ref={mapContainerRef} className="w-full h-full" />
    </div>
  );
}

import { useEffect, useRef, useState, useMemo } from 'react';
import { useSearchParams } from 'react-router';
import L from 'leaflet';
import { DEMO_RADAR_TIMESTAMP } from '../data/demoData';
import type { GeoJSONGeometry, Droplet } from '../types';

interface RainAreaMapProps {
  rainZone: GeoJSONGeometry | null;
  userLocation: { latitude: number; longitude: number } | null;
  droplets: Droplet[];
}

export function RainAreaMap({ rainZone, userLocation, droplets }: RainAreaMapProps) {
  const [searchParams] = useSearchParams();
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const radarLayerRef = useRef<L.TileLayer | null>(null);
  const layersRef = useRef<{
    zoneLayer: L.GeoJSON | null;
    userMarker: L.Marker | null;
    dropletMarkers: L.Marker[];
  }>({
    zoneLayer: null,
    userMarker: null,
    dropletMarkers: [],
  });

  // Check if demo mode is enabled
  const isDemoMode = searchParams.get('demo') === 'true';

  // Initialize radar timestamp (demo mode uses fixed snapshot)
  const initialTimestamp = useMemo(
    () => (isDemoMode ? DEMO_RADAR_TIMESTAMP : null),
    [isDemoMode]
  );
  const [radarTimestamp, setRadarTimestamp] = useState<number | null>(initialTimestamp);

  // Fetch live radar timestamp (skip in demo mode)
  useEffect(() => {
    if (isDemoMode) {
      return;
    }

    const fetchRadarTimestamp = async () => {
      try {
        const response = await fetch('https://api.rainviewer.com/public/weather-maps.json');
        const data = await response.json();
        if (data.radar && data.radar.past && data.radar.past.length > 0) {
          // Get the most recent radar frame
          const latest = data.radar.past[data.radar.past.length - 1];
          setRadarTimestamp(latest.time);
        }
      } catch (error) {
        console.error('Failed to fetch radar timestamp:', error);
      }
    };

    fetchRadarTimestamp();
    // Refresh radar every 5 minutes
    const interval = setInterval(fetchRadarTimestamp, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, [isDemoMode]);

  // Initialize map on mount
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [0, 0],
      zoom: 2,
      scrollWheelZoom: false,
      attributionControl: false, // Disable default attribution
    });

    // Use CartoDB Positron for a cleaner, minimal base map with muted roads
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      maxZoom: 19,
      subdomains: 'abcd',
    }).addTo(map);

    // Create custom collapsible attribution control
    const AttributionControl = L.Control.extend({
      options: {
        position: 'bottomright',
      },
      onAdd: function () {
        const container = L.DomUtil.create('div', 'leaflet-control-attribution-custom');
        container.style.cssText = 'background: white; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.3); cursor: pointer; user-select: none;';

        const icon = L.DomUtil.create('div', 'attribution-icon', container);
        icon.innerHTML = 'ⓘ';
        icon.style.cssText = 'width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 14px; color: #666;';

        const content = L.DomUtil.create('div', 'attribution-content', container);
        content.innerHTML = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> | <a href="https://carto.com/attributions" target="_blank">CARTO</a> | <a href="https://rainviewer.com" target="_blank">RainViewer</a> | <a href="https://leafletjs.com" target="_blank">Leaflet</a>';
        content.style.cssText = 'display: none; padding: 4px 8px; font-size: 11px; white-space: nowrap; border-top: 1px solid #eee; margin-top: 4px;';

        let isExpanded = false;

        L.DomEvent.on(icon, 'click', function (e) {
          L.DomEvent.stopPropagation(e);
          isExpanded = !isExpanded;
          if (isExpanded) {
            content.style.display = 'block';
            icon.style.backgroundColor = '#f0f0f0';
          } else {
            content.style.display = 'none';
            icon.style.backgroundColor = 'transparent';
          }
        });

        // Prevent map interactions on the control
        L.DomEvent.disableClickPropagation(container);
        L.DomEvent.disableScrollPropagation(container);

        return container;
      },
    });

    map.addControl(new AttributionControl());

    mapRef.current = map;

    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  // Add/update radar layer when timestamp changes
  useEffect(() => {
    if (!mapRef.current || !radarTimestamp) return;

    const map = mapRef.current;

    // Remove old radar layer if it exists
    if (radarLayerRef.current) {
      map.removeLayer(radarLayerRef.current);
    }

    // Add new radar layer with latest timestamp
    const radarLayer = L.tileLayer(
      `https://tilecache.rainviewer.com/v2/radar/${radarTimestamp}/256/{z}/{x}/{y}/6/1_1.png`,
      {
        opacity: 0.6,
        zIndex: 500, // Above base layer but below markers
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

    // Add rain zone polygon (but don't include it in bounds for zoom calculation)
    if (rainZone) {
      const zoneLayer = L.geoJSON(rainZone as GeoJSON.Geometry, {
        style: {
          color: '#3b82f6',
          weight: 2,
          opacity: 0.7,
          fillColor: '#3b82f6',
          fillOpacity: 0.1,
        },
      }).addTo(map);

      layers.zoneLayer = zoneLayer;
      // Don't extend bounds with rain zone - focus on droplets/user for tight local view
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

    // Auto-fit map to show all content with zoomed-in view
    if (hasContent && bounds.isValid()) {
      // For local view, use very tight bounds with high zoom for close-up perspective
      map.fitBounds(bounds, {
        padding: [15, 15] as [number, number],
        maxZoom: 9,
      });
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

import { useEffect, useRef, useState, useMemo } from 'react';
import L from 'leaflet';
import 'leaflet.markercluster';
import { DEMO_RADAR_TIMESTAMP } from '../data/demoData';
import type { GeoJSONGeometry, Droplet } from '../types';

interface GlobalMapProps {
  rainZones: GeoJSONGeometry[];
  userLocation: { latitude: number; longitude: number } | null;
  droplets: Droplet[];
}

export function GlobalMap({ rainZones, userLocation, droplets }: GlobalMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const radarLayerRef = useRef<L.TileLayer | null>(null);
  const layersRef = useRef<{
    zoneLayers: L.GeoJSON[];
    userMarker: L.Marker | null;
    markerClusterGroup: L.MarkerClusterGroup | null;
  }>({
    zoneLayers: [],
    userMarker: null,
    markerClusterGroup: null,
  });
  const [radarTimestamp, setRadarTimestamp] = useState<number | null>(null);

  // Check if demo mode is enabled
  const isDemoMode = useMemo(() => {
    const params = new URLSearchParams(window.location.search);
    return params.get('demo') === 'true';
  }, []);

  // Set radar timestamp (demo mode uses fixed snapshot, otherwise fetch live)
  useEffect(() => {
    if (isDemoMode) {
      setRadarTimestamp(DEMO_RADAR_TIMESTAMP);
      return;
    }

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
  }, [isDemoMode]);

  // Initialize map on mount
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [0, 0],
      zoom: 2,
      scrollWheelZoom: false,
      attributionControl: false,
    });

    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      maxZoom: 19,
      subdomains: 'abcd',
    }).addTo(map);

    // Create custom attribution control
    const AttributionControl = L.Control.extend({
      options: {
        position: 'bottomright',
      },
      onAdd: function () {
        const container = L.DomUtil.create('div', 'leaflet-control-attribution-custom');
        container.style.cssText =
          'background: white; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.3); cursor: pointer; user-select: none;';

        const icon = L.DomUtil.create('div', 'attribution-icon', container);
        icon.innerHTML = 'ⓘ';
        icon.style.cssText =
          'width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 14px; color: #666;';

        const content = L.DomUtil.create('div', 'attribution-content', container);
        content.innerHTML =
          '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> | <a href="https://carto.com/attributions" target="_blank">CARTO</a> | <a href="https://rainviewer.com" target="_blank">RainViewer</a> | <a href="https://leafletjs.com" target="_blank">Leaflet</a>';
        content.style.cssText =
          'display: none; padding: 4px 8px; font-size: 11px; white-space: nowrap; border-top: 1px solid #eee; margin-top: 4px;';

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

  // Update layers when data changes
  useEffect(() => {
    if (!mapRef.current) return;

    const map = mapRef.current;
    const layers = layersRef.current;

    // Clear existing layers
    layers.zoneLayers.forEach((layer) => map.removeLayer(layer));
    layers.zoneLayers = [];

    if (layers.userMarker) {
      map.removeLayer(layers.userMarker);
      layers.userMarker = null;
    }

    if (layers.markerClusterGroup) {
      map.removeLayer(layers.markerClusterGroup);
      layers.markerClusterGroup = null;
    }

    const bounds = L.latLngBounds([]);
    let hasContent = false;

    // Add all rain zone polygons
    rainZones.forEach((zone) => {
      const zoneLayer = L.geoJSON(zone as any, {
        style: {
          color: '#3b82f6',
          weight: 2,
          opacity: 0.6,
          fillColor: '#3b82f6',
          fillOpacity: 0.1,
        },
      }).addTo(map);

      layers.zoneLayers.push(zoneLayer);
      bounds.extend(zoneLayer.getBounds());
      hasContent = true;
    });

    // Add user location marker
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

    // Create marker cluster group for droplets
    const markerClusterGroup = L.markerClusterGroup({
      showCoverageOnHover: false,
      maxClusterRadius: 60,
      disableClusteringAtZoom: 15,
      spiderfyOnMaxZoom: true,
      zoomToBoundsOnClick: true,
    });

    // Add droplet markers to cluster group
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
      });

      marker.bindPopup(
        `<div style="min-width: 150px;">
          <p style="font-weight: 600; margin-bottom: 4px;">${droplet.user.email}</p>
          <p style="margin-bottom: 0;">${droplet.content}</p>
        </div>`
      );

      markerClusterGroup.addLayer(marker);
      bounds.extend(marker.getLatLng());
      hasContent = true;
    });

    map.addLayer(markerClusterGroup);
    layers.markerClusterGroup = markerClusterGroup;

    // Auto-fit map to show all content (no maxZoom limit for global view)
    if (hasContent && bounds.isValid()) {
      map.fitBounds(bounds, { padding: [50, 50] });
    } else {
      map.setView([0, 0], 2);
    }
  }, [rainZones, userLocation, droplets]);

  return (
    <div className="w-full h-[300px] md:h-[400px] rounded-lg overflow-hidden shadow-sm border border-gray-200">
      <div ref={mapContainerRef} className="w-full h-full" />
    </div>
  );
}

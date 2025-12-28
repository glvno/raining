export interface User {
  id: number;
  email: string;
  confirmed_at?: string;
  authenticated_at?: string;
}

export interface Droplet {
  id: number;
  content: string;
  latitude: number;
  longitude: number;
  user: User;
  inserted_at: string;
  updated_at: string;
}

export interface GeoJSONGeometry {
  type: string;
  coordinates: number[][][];
}

export interface FeedResponse {
  droplets: Droplet[];
  count: number;
  time_window_hours?: number;
  message?: string;
  rain_zone: GeoJSONGeometry | null;
}

export interface LoginResponse {
  token: string;
  user: User;
}

export interface DropletCreateParams {
  content: string;
  latitude: number;
  longitude: number;
}

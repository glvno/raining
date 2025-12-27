import type { ReactNode } from 'react';
import { Navigate } from 'react-router';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { LockoutScreen } from './LockoutScreen';

interface ProtectedRouteProps {
  children: ReactNode;
}

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { isAuthenticated, isLoading: authLoading } = useAuth();
  const { isRaining, isLoading: locationLoading, error: locationError } = useLocation();

  // Show loading state while checking auth or location
  if (authLoading || locationLoading) {
    return (
      <div className="min-h-full flex items-center justify-center bg-gray-50">
        <div className="text-center space-y-4">
          <div className="text-4xl animate-pulse">🌧️</div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  // Redirect to login if not authenticated
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // Show location error if there's an issue getting location
  if (locationError) {
    return (
      <div className="min-h-full flex items-center justify-center bg-gray-50">
        <div className="text-center space-y-4 px-4">
          <div className="text-4xl">⚠️</div>
          <h2 className="text-2xl font-bold text-gray-800">Location Error</h2>
          <p className="text-gray-600">{locationError}</p>
          <p className="text-sm text-gray-500">
            Please enable location permissions and refresh the page
          </p>
        </div>
      </div>
    );
  }

  // Show lockout screen if authenticated but not raining
  if (!isRaining) {
    return <LockoutScreen />;
  }

  // All checks passed - render protected content
  return <>{children}</>;
}

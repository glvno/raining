import type { Droplet } from '../types';
import { formatRelativeTime } from '../utils/formatDate';

interface DropletCardProps {
  droplet: Droplet;
}

export function DropletCard({ droplet }: DropletCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-2">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-semibold">
            {droplet.user.email.charAt(0).toUpperCase()}
          </div>
          <div>
            <p className="font-medium text-gray-900">{droplet.user.email}</p>
            <p className="text-sm text-gray-500">{formatRelativeTime(droplet.inserted_at)}</p>
          </div>
        </div>
      </div>

      <p className="text-gray-800 whitespace-pre-wrap break-words">{droplet.content}</p>

      <div className="mt-3 flex items-center gap-2 text-xs text-gray-400">
        <span>📍</span>
        <span>
          {droplet.latitude.toFixed(2)}, {droplet.longitude.toFixed(2)}
        </span>
      </div>
    </div>
  );
}

import { useState } from 'react';
import type { FormEvent } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import type { Droplet } from '../types';

const API_BASE = '/api';
const MAX_CHARS = 500;

interface DropletComposerProps {
  onDropletCreated: (droplet: Droplet) => void;
}

export function DropletComposer({ onDropletCreated }: DropletComposerProps) {
  const [content, setContent] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { token } = useAuth();
  const { latitude, longitude } = useLocation();

  const charCount = content.length;
  const isDisabled = charCount === 0 || charCount > MAX_CHARS || isSubmitting;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!latitude || !longitude) {
      setError('Location not available');
      return;
    }

    if (isDisabled) {
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE}/droplets`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          droplet: {
            content,
            latitude,
            longitude,
          },
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to post droplet');
      }

      const data = await response.json();
      onDropletCreated(data.droplet);
      setContent('');
      setError(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to post droplet';
      setError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-6">
      <form onSubmit={handleSubmit}>
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="What's happening in the rain?"
          className="w-full text-gray-900 p-3 border border-gray-300 rounded-lg resize-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          rows={3}
          disabled={isSubmitting}
        />

        <div className="mt-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span
              className={`text-sm font-medium ${charCount > MAX_CHARS
                ? 'text-red-600'
                : charCount > MAX_CHARS * 0.9
                  ? 'text-orange-600'
                  : 'text-gray-500'
                }`}
            >
              {charCount} / {MAX_CHARS}
            </span>
          </div>

          <button
            type="submit"
            disabled={isDisabled}
            className={`px-6 py-2 rounded-full font-medium transition-colors ${isDisabled
              ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
              : 'bg-blue-500 text-white hover:bg-blue-600'
              }`}
          >
            {isSubmitting ? 'Posting...' : 'Post'}
          </button>
        </div>

        {error && (
          <div className="mt-3 p-3 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}
      </form>
    </div>
  );
}

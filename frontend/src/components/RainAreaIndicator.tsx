interface RainAreaIndicatorProps {
  dropletCount: number;
}

export function RainAreaIndicator({ dropletCount }: RainAreaIndicatorProps) {
  return (
    <div className="bg-blue-100 text-blue-800 px-4 py-2 rounded-full inline-flex items-center gap-2">
      <span className="text-xl">🌧️</span>
      <span className="font-medium">
        {dropletCount} droplet{dropletCount !== 1 ? 's' : ''} in your rain area
      </span>
    </div>
  );
}

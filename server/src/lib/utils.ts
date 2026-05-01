import { clsx, type ClassValue } from 'clsx';

export function cn(...inputs: ClassValue[]) {
  return clsx(inputs);
}

export function formatRelative(timestamp?: string | null): string {
  if (!timestamp) return 'No requests yet';
  const diffMs = Date.now() - new Date(timestamp).getTime();
  const seconds = Math.max(0, Math.round(diffMs / 1000));
  if (seconds < 5) return 'Just now';
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  return `${hours}h ago`;
}

export function titleCase(value?: string | null): string {
  if (!value) return 'Unknown';
  return value.replaceAll('_', ' ').replace(/\b\w/g, (char) => char.toUpperCase());
}

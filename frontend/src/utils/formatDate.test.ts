import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { formatRelativeTime } from './formatDate';

describe('formatRelativeTime', () => {
  beforeEach(() => {
    // Mock Date.now to return a fixed timestamp
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2024-01-15T12:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('returns "just now" for times less than 60 seconds ago', () => {
    const date = new Date('2024-01-15T11:59:30Z').toISOString();
    expect(formatRelativeTime(date)).toBe('just now');
  });

  it('returns "1 minute ago" for exactly 1 minute ago', () => {
    const date = new Date('2024-01-15T11:59:00Z').toISOString();
    expect(formatRelativeTime(date)).toBe('1 minute ago');
  });

  it('returns "X minutes ago" for times less than an hour ago', () => {
    const date = new Date('2024-01-15T11:30:00Z').toISOString();
    expect(formatRelativeTime(date)).toBe('30 minutes ago');
  });

  it('returns "1 hour ago" for exactly 1 hour ago', () => {
    const date = new Date('2024-01-15T11:00:00Z').toISOString();
    expect(formatRelativeTime(date)).toBe('1 hour ago');
  });

  it('returns "X hours ago" for times less than 24 hours ago', () => {
    const date = new Date('2024-01-15T06:00:00Z').toISOString();
    expect(formatRelativeTime(date)).toBe('6 hours ago');
  });

  it('returns "1 day ago" for exactly 1 day ago', () => {
    const date = new Date('2024-01-14T12:00:00Z').toISOString();
    expect(formatRelativeTime(date)).toBe('1 day ago');
  });

  it('returns "X days ago" for times less than 7 days ago', () => {
    const date = new Date('2024-01-12T12:00:00Z').toISOString();
    expect(formatRelativeTime(date)).toBe('3 days ago');
  });

  it('returns formatted date for times 7+ days ago', () => {
    const date = new Date('2024-01-01T12:00:00Z').toISOString();
    const result = formatRelativeTime(date);
    // Should return a locale date string (format varies by locale)
    expect(result).toMatch(/\d/);
    expect(result).not.toContain('ago');
  });
});

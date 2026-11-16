import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {sitePath} from '@/lib/site-path';

beforeEach(() => {
  vi.stubGlobal('location', new URL('https://watchclub.example.com/sign-in'));
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('sitePath', () => {
  it('keeps a path on this site, with its query and fragment', () => {
    expect(sitePath('/settings?tab=1#language')).toBe('/settings?tab=1#language');
  });

  it('turns an address on this site into its path', () => {
    expect(sitePath('https://watchclub.example.com/settings')).toBe('/settings');
  });

  it('rejects an address on another site, however it is written', () => {
    for (const address of [
      'https://evil.example.com/',
      '//evil.example.com/',
      '/\\evil.example.com/',
      '/\t/evil.example.com/',
      '/\n/evil.example.com/',
      'https://watchclub.example.com//evil.example.com/',
      '/settings/..//evil.example.com/',
      'javascript:alert(1)',
    ]) {
      expect(sitePath(address)).toBeUndefined();
    }
  });

  it('rejects what is not an address', () => {
    expect(sitePath(undefined)).toBeUndefined();
    expect(sitePath(42)).toBeUndefined();
    expect(sitePath('http://[')).toBeUndefined();
  });
});

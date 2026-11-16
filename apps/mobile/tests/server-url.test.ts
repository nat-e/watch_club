import {describe, expect, it} from 'vitest';
import {serverUrl} from '@/server-url';

describe('serverUrl', () => {
  it('uses HTTPS unless the address says otherwise', () => {
    expect(serverUrl(' watchclub.example.com ')).toBe('https://watchclub.example.com');
    expect(serverUrl('HTTP://192.168.1.10:4000/')).toBe('http://192.168.1.10:4000');
  });

  it('keeps the path of a server behind a reverse proxy', () => {
    expect(serverUrl('example.com/watchclub/')).toBe('https://example.com/watchclub');
  });

  it("rejects what isn't an address", () => {
    expect(serverUrl('')).toBeNull();
    expect(serverUrl('my watchclub')).toBeNull();
    expect(serverUrl('ftp://example.com')).toBeNull();
    expect(serverUrl('example.com?x=1')).toBeNull();
  });
});

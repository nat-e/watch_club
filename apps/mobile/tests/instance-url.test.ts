import {afterEach, describe, expect, it, vi} from 'vitest';
import {checkInstance, instanceUrl} from '@/instance-url';

/** The answer of an Instance that's set up. */
// biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
const SET_UP = {version: '1.0.0', needs_setup: false};

/** Answers `GET /api/instance` at the URL with the body, as the app at that address would. */
function serve(url: string, body: unknown) {
  vi.stubGlobal('fetch', (request: Request) =>
    request.url === `${url}/api/instance`
      ? Promise.resolve(Response.json(body))
      : Promise.reject(new TypeError('Failed to fetch')),
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('instanceUrl', () => {
  it('uses HTTPS unless the address says otherwise', () => {
    expect(instanceUrl(' watchclub.example.com ')).toBe('https://watchclub.example.com');
    expect(instanceUrl('HTTP://192.168.1.10:4000/')).toBe('http://192.168.1.10:4000');
  });

  it('keeps the path of an Instance behind a reverse proxy', () => {
    expect(instanceUrl('example.com/watchclub/')).toBe('https://example.com/watchclub');
  });

  it("rejects what isn't an address", () => {
    expect(instanceUrl('')).toBeNull();
    expect(instanceUrl('my watchclub')).toBeNull();
    expect(instanceUrl('ftp://example.com')).toBeNull();
    expect(instanceUrl('example.com?x=1')).toBeNull();
  });
});

describe('checkInstance', () => {
  it('accepts a WatchClub that is set up', async () => {
    serve('https://watchclub.example.com', SET_UP);
    expect(await checkInstance('watchclub.example.com')).toEqual({
      url: 'https://watchclub.example.com',
    });
  });

  it("rejects what isn't an address", async () => {
    expect(await checkInstance('my watchclub')).toEqual({error: 'invalidAddress'});
  });

  it('rejects an address where no WatchClub answers', async () => {
    serve('https://watchclub.example.com', SET_UP);
    expect(await checkInstance('other.example.com')).toEqual({error: 'unreachable'});
    serve('https://other.example.com', {name: 'another app'});
    expect(await checkInstance('other.example.com')).toEqual({error: 'unreachable'});
  });

  it("rejects a WatchClub that isn't set up yet", async () => {
    // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
    serve('https://watchclub.example.com', {version: '1.0.0', needs_setup: true});
    expect(await checkInstance('watchclub.example.com')).toEqual({error: 'needsSetup'});
  });
});

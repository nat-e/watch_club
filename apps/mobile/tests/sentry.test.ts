import type {ErrorEvent, ReactNativeOptions} from '@sentry/react-native';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';

const {init, close, clearScope, storage} = vi.hoisted(() => ({
  init: vi.fn<(options: ReactNativeOptions) => void>(),
  close: vi.fn(() => Promise.resolve()),
  clearScope: vi.fn(),
  storage: new Map<string, string>(),
}));

vi.mock('@sentry/react-native', () => ({
  init,
  close,
  getIsolationScope: () => ({clear: clearScope}),
  getCurrentScope: () => ({clear: clearScope}),
}));

vi.mock('expo-secure-store', () => ({
  getItemAsync: (key: string) => Promise.resolve(storage.get(key) ?? null),
  setItemAsync: (key: string, value: string) => {
    storage.set(key, value);
    return Promise.resolve();
  },
  deleteItemAsync: (key: string) => {
    storage.delete(key);
    return Promise.resolve();
  },
}));

const INSTANCE = 'https://watchclub.example.com';
const OTHER_INSTANCE = 'https://other.example.com';
const DSN = 'https://key@sentry.example.com/2';
const OTHER_DSN = 'https://key@sentry.example.org/7';

/** The Sentry project each fake Instance names, or null for none. Instances not listed are down. */
let instances: {[instanceUrl: string]: string | null};

/** Answers `GET /api/instance` as each Instance in `instances` would. */
function fakeInstances() {
  vi.stubGlobal('fetch', async (request: Request) => {
    const url = new URL(request.url);
    const dsn = instances[url.origin];
    if (dsn === undefined) {
      throw new TypeError('Failed to fetch');
    }
    return Response.json({
      name: 'WatchClub',
      version: '0.1.0',
      // biome-ignore-start lint/style/useNamingConvention: the API uses snake_case field names
      needs_setup: false,
      web_sentry_dsn: null,
      mobile_sentry_dsn: dsn,
      sentry_environment: 'staging',
      // biome-ignore-end lint/style/useNamingConvention: the API uses snake_case field names
    });
  });
}

/** Loads the app's Sentry module afresh, as at a new launch. */
async function launch() {
  vi.resetModules();
  return await import('@/sentry');
}

/** Returns the options Sentry last started with. */
function lastOptions(): ReactNativeOptions {
  const [options] = init.mock.lastCall ?? [];
  if (!options) {
    throw new Error('Sentry did not start');
  }
  return options;
}

beforeEach(() => {
  instances = {};
  fakeInstances();
});

afterEach(() => {
  vi.unstubAllGlobals();
  init.mockReset();
  close.mockClear();
  clearScope.mockClear();
  storage.clear();
});

describe('startSentry', () => {
  it('leaves Sentry off until an Instance names a Sentry project', async () => {
    const {startSentry} = await launch();

    await startSentry();

    expect(init).not.toHaveBeenCalled();
  });

  it("starts with the Instance's project saved at the last launch, before reaching it", async () => {
    instances[INSTANCE] = DSN;
    await (await launch()).reportToInstance(INSTANCE);
    init.mockReset();
    delete instances[INSTANCE];
    const {startSentry} = await launch();

    await startSentry();

    expect(lastOptions()).toMatchObject({dsn: DSN, environment: 'staging'});
  });
});

describe('reportToInstance', () => {
  it("reports to the Instance's project, in its environment", async () => {
    instances[INSTANCE] = DSN;
    const {startSentry, reportToInstance} = await launch();
    await startSentry();

    await reportToInstance(INSTANCE);

    expect(lastOptions()).toMatchObject({dsn: DSN, environment: 'staging'});
  });

  it('restarts with the other project once the app moves to another Instance', async () => {
    instances[INSTANCE] = DSN;
    instances[OTHER_INSTANCE] = OTHER_DSN;
    const {reportToInstance} = await launch();
    await reportToInstance(INSTANCE);

    await reportToInstance(OTHER_INSTANCE);

    expect(close).toHaveBeenCalledOnce();
    expect(lastOptions()).toMatchObject({dsn: OTHER_DSN});
  });

  it("forgets what it noted on the other Instance, such as its requests' addresses", async () => {
    instances[INSTANCE] = DSN;
    instances[OTHER_INSTANCE] = DSN;
    const {reportToInstance} = await launch();
    await reportToInstance(INSTANCE);

    await reportToInstance(OTHER_INSTANCE);

    expect(clearScope).toHaveBeenCalled();
  });

  it('stays off while the other Instance it moved to does not answer', async () => {
    instances[INSTANCE] = DSN;
    const {reportToInstance} = await launch();
    await reportToInstance(INSTANCE);
    init.mockReset();

    await reportToInstance(OTHER_INSTANCE);

    expect(close).toHaveBeenCalledOnce();
    expect(init).not.toHaveBeenCalled();
    expect(storage.size).toBe(0);
  });

  it('reports to the first Instance again after the other did not answer', async () => {
    instances[INSTANCE] = DSN;
    const {reportToInstance} = await launch();
    await reportToInstance(INSTANCE);
    await reportToInstance(OTHER_INSTANCE);
    init.mockReset();

    await reportToInstance(INSTANCE);

    expect(lastOptions()).toMatchObject({dsn: DSN});
  });

  it('starts for another Instance without what Sentry noted while it was off', async () => {
    instances[INSTANCE] = DSN;
    instances[OTHER_INSTANCE] = OTHER_DSN;
    const {reportToInstance} = await launch();
    await reportToInstance(INSTANCE);
    clearScope.mockClear();

    await reportToInstance(OTHER_INSTANCE);

    // Cleared just before Sentry starts again
    expect(clearScope.mock.invocationCallOrder.at(-1)).toBeLessThan(
      init.mock.invocationCallOrder.at(-1) ?? 0,
    );
  });

  it('asks the Instance again after it did not answer', async () => {
    const {reportToInstance} = await launch();
    await reportToInstance(INSTANCE);
    instances[INSTANCE] = DSN;

    await reportToInstance(INSTANCE);

    expect(lastOptions()).toMatchObject({dsn: DSN});
  });

  it('stops, and forgets the project, once the Instance names none', async () => {
    instances[INSTANCE] = DSN;
    instances[OTHER_INSTANCE] = null;
    const {reportToInstance} = await launch();
    await reportToInstance(INSTANCE);

    await reportToInstance(OTHER_INSTANCE);

    expect(close).toHaveBeenCalledOnce();
    expect(storage.size).toBe(0);
  });

  it("leaves Sentry as it is when the Instance doesn't answer", async () => {
    instances[INSTANCE] = DSN;
    await (await launch()).reportToInstance(INSTANCE);
    delete instances[INSTANCE];
    const {startSentry, reportToInstance} = await launch();
    await startSentry();

    await reportToInstance(INSTANCE);

    expect(close).not.toHaveBeenCalled();
    expect(lastOptions()).toMatchObject({dsn: DSN});
  });

  it("keeps the User's IP address from Sentry", async () => {
    instances[INSTANCE] = DSN;
    const {reportToInstance} = await launch();

    await reportToInstance(INSTANCE);

    expect(lastOptions().sendDefaultPii).toBe(false);
  });

  it('leaves out failed requests to the Instance, which it reports or the network causes', async () => {
    instances[INSTANCE] = DSN;
    const {reportToInstance} = await launch();
    // The errors of the API module the launch loaded, which the app checks against
    const {ApiError, UnexpectedError} = await import('@watchclub/api');
    await reportToInstance(INSTANCE);
    const {beforeSend} = lastOptions();
    const event: ErrorEvent = {type: undefined, message: 'failed'};

    const failures = [
      new ApiError({code: 'unauthorized', message: 'not signed in'}),
      new UnexpectedError({}, 500),
    ];
    for (const error of failures) {
      expect(beforeSend?.(event, {originalException: error})).toBeNull();
    }
    expect(beforeSend?.(event, {originalException: new TypeError('bug')})).toBe(event);
  });
});

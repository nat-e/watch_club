import type {ErrorEvent, ReactNativeOptions} from '@sentry/react-native';
import {ApiError, UnexpectedError} from '@watchclub/api';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {startSentry} from '@/sentry';

const {init} = vi.hoisted(() => ({init: vi.fn<(options: ReactNativeOptions) => void>()}));
vi.mock('@sentry/react-native', () => ({init}));

afterEach(() => {
  vi.unstubAllEnvs();
  init.mockReset();
});

/** Starts Sentry in a build with a DSN, and returns the options it started with. */
function start(): ReactNativeOptions {
  vi.stubEnv('EXPO_PUBLIC_SENTRY_DSN', 'https://key@sentry.example.com/1');
  startSentry();
  const [options] = init.mock.lastCall ?? [];
  if (!options) {
    throw new Error('Sentry did not start');
  }
  return options;
}

describe('startSentry', () => {
  it('leaves Sentry off in builds without a DSN', () => {
    vi.stubEnv('EXPO_PUBLIC_SENTRY_DSN', '');

    startSentry();

    expect(init).not.toHaveBeenCalled();
  });

  it("keeps the Instance's address out of breadcrumbs", () => {
    const {beforeBreadcrumb} = start();

    const breadcrumb = beforeBreadcrumb?.({
      category: 'fetch',
      data: {method: 'GET', url: 'https://watchclub.example.com:8443/club/api/me?page=2'},
    });

    expect(breadcrumb?.data).toEqual({method: 'GET', url: '/club/api/me?page=2'});
  });

  it('leaves out failed requests to the Instance, which it reports or the network causes', () => {
    const {beforeSend} = start();
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

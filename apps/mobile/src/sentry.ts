/**
 * Reports the app's crashes and errors to the Sentry project in `EXPO_PUBLIC_SENTRY_DSN`, which our
 * builds set and others leave out. The reports come to us, rather than to the Instances the app
 * signs in to, so they leave out the Instances' addresses.
 */
import * as sentry from '@sentry/react-native';
import {isRequestFailure} from '@watchclub/api';

/** Starts Sentry in builds that name a DSN. Call it before anything else the app runs. */
export function startSentry() {
  const dsn = process.env.EXPO_PUBLIC_SENTRY_DSN;
  if (!dsn) {
    return;
  }
  sentry.init({
    dsn,
    // Starts the native SDK from here, even when Expo's config plugin writes an options file, which
    // would otherwise expect the native code to start it
    autoInitializeNativeSdk: true,
    // Keeps Sentry's headers out of the requests to the Instances
    tracePropagationTargets: [],
    // The native iOS SDK's breadcrumbs of requests, which hold the Instances' addresses. The ones
    // of JavaScript's requests remain, without them
    enableNetworkBreadcrumbs: false,
    beforeSend: (event, hint) => (isRequestFailure(hint.originalException) ? null : event),
    beforeBreadcrumb: breadcrumb => {
      const url: unknown = breadcrumb.data?.url;
      return typeof url === 'string'
        ? {...breadcrumb, data: {...breadcrumb.data, url: withoutOrigin(url)}}
        : breadcrumb;
    },
  });
}

/** Returns the URL's path and query, such as `/api/me`, without its scheme and host. */
function withoutOrigin(url: string): string {
  return url.replace(/^[a-z][a-z\d+.-]*:\/\/[^/?#]*/i, '');
}

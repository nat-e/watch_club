/**
 * Reports the web app's errors to the Sentry project the host names with `SENTRY_WEB_DSN`. The app
 * only downloads the Sentry SDK then.
 */
import type {QueryClient} from '@tanstack/react-query';
import {getInstanceOptions, isRequestFailure} from '@watchclub/api';
import type {ErrorInfo} from 'react';

/** Reports an error with React's details on it, once Sentry has started. */
let captureReactException: ((error: unknown, errorInfo: ErrorInfo) => void) | undefined;

/** Starts Sentry if the Instance names a DSN. Errors before then only reach the console. */
export async function startSentry(queryClient: QueryClient): Promise<void> {
  const instance = await queryClient.fetchQuery(getInstanceOptions());
  if (instance.web_sentry_dsn === null) {
    return;
  }
  // Only what the app uses, so the bundler leaves the rest of the SDK out
  const {init, captureReactException: capture} = await import('@sentry/react');
  init({
    dsn: instance.web_sentry_dsn,
    release: `watch_club@${instance.version}`,
    // The server's, so that Sentry shows a deployment's reports together
    environment: instance.sentry_environment,
    // Keeps the User's IP address from Sentry, which would store it otherwise
    dataCollection: {userInfo: false},
    beforeSend: (event, hint) => (isRequestFailure(hint.originalException) ? null : event),
  });
  captureReactException = capture;
}

/**
 * Logs an error that React caught, or couldn't, and reports it to Sentry once it has started. Pass
 * it to `createRoot`'s callbacks, which replace React's own logging.
 */
export function reportReactError(error: unknown, errorInfo: ErrorInfo) {
  console.error(error);
  captureReactException?.(error, errorInfo);
}

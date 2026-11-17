/**
 * Reports the app's crashes and errors to the Sentry project of the Instance it talks to, which the
 * Instance's host names with `SENTRY_MOBILE_DSN`, as the web app reports to the one in
 * `SENTRY_WEB_DSN`. The app saves the Instance's settings, so that it reports the crashes of its
 * next launch before it reaches the Instance.
 */
import * as sentry from '@sentry/react-native';
import {getInstance, isRequestFailure} from '@watchclub/api';
import * as secureStore from 'expo-secure-store';

const INSTANCE_URL_KEY = 'sentry-instance-url';
const DSN_KEY = 'sentry-dsn';
const ENVIRONMENT_KEY = 'sentry-environment';

/** The Instance whose Sentry project gets the reports, and the environment they name. */
interface Reporting {
  readonly instanceUrl: string;
  readonly dsn: string;
  readonly environment: string;
}

/** What Sentry reports with, or null while it's off. */
let running: Reporting | null = null;

/** The Instance whose settings the app got during this launch, or null before it gets any. */
let followedInstanceUrl: string | null = null;

/** The changes to Sentry, one after the other, so that a later one can't finish first. */
let changes = Promise.resolve();

/**
 * Starts Sentry with the settings the app saved from its Instance, if any, and returns once it
 * has. Call it before anything else the app runs.
 */
export function startSentry(): Promise<void> {
  return change(async () => {
    const saved = await readSaved();
    if (saved !== null) {
      start(saved);
    }
  });
}

/**
 * Makes Sentry report to the Instance's Sentry project: asks the Instance for its settings, then
 * starts, restarts or stops Sentry to match them, and saves them for the next launch. Until another
 * Instance answers, Sentry stays off, so that neither Instance gets the other's reports. Call it
 * whenever the app's Instance may have changed; it returns once Sentry follows the Instance, and
 * asks again on the next call when the Instance didn't answer.
 */
export function reportToInstance(instanceUrl: string | null): Promise<void> {
  if (instanceUrl === null) {
    return changes;
  }
  return change(async () => {
    if (instanceUrl === followedInstanceUrl) {
      return;
    }
    // Until the Instance answers, so that the next call asks it again
    followedInstanceUrl = null;
    if (running !== null && running.instanceUrl !== instanceUrl) {
      await stop();
      await save(null);
    }
    const {data} = await getInstance({baseUrl: instanceUrl});
    if (!data) {
      return;
    }
    followedInstanceUrl = instanceUrl;
    // Instances from before SENTRY_MOBILE_DSN don't say
    const reporting: Reporting | null =
      typeof data.mobile_sentry_dsn === 'string'
        ? {instanceUrl, dsn: data.mobile_sentry_dsn, environment: data.sentry_environment}
        : null;
    if (!isSame(reporting, running)) {
      if (running !== null) {
        await stop();
      }
      if (reporting !== null) {
        start(reporting);
      }
    }
    await save(reporting);
  });
}

/** Runs the change once the ones before it end, logs its failure, and returns once it ends. */
function change(task: () => Promise<void>): Promise<void> {
  changes = changes.then(task).catch((error: unknown) => {
    console.error(error);
  });
  return changes;
}

/**
 * Starts Sentry for the Instance, from empty scopes: a stopped Sentry still notes breadcrumbs, such
 * as the requests to another Instance.
 */
function start(reporting: Reporting) {
  sentry.getIsolationScope().clear();
  sentry.getCurrentScope().clear();
  sentry.init({
    dsn: reporting.dsn,
    environment: reporting.environment,
    // Starts the native SDK from here, even when Expo's config plugin writes an options file, which
    // would otherwise expect the native code to start it
    autoInitializeNativeSdk: true,
    // Keeps the User's IP address from Sentry, which would infer it otherwise
    sendDefaultPii: false,
    beforeSend: (event, hint) => (isRequestFailure(hint.originalException) ? null : event),
  });
  running = reporting;
}

/** Stops Sentry, and the native SDK with it, which `init` starts again. */
async function stop() {
  await sentry.close();
  running = null;
}

function isSame(reporting: Reporting | null, other: Reporting | null): boolean {
  return (
    reporting?.instanceUrl === other?.instanceUrl &&
    reporting?.dsn === other?.dsn &&
    reporting?.environment === other?.environment
  );
}

/** Returns the settings saved from the Instance, or null when there are none or they can't be read. */
async function readSaved(): Promise<Reporting | null> {
  const [instanceUrl, dsn, environment] = await Promise.all([
    secureStore.getItemAsync(INSTANCE_URL_KEY),
    secureStore.getItemAsync(DSN_KEY),
    secureStore.getItemAsync(ENVIRONMENT_KEY),
  ]).catch(() => [null, null, null]);
  return instanceUrl === null || dsn === null || environment === null
    ? null
    : {instanceUrl, dsn, environment};
}

/** Saves the Instance's settings for the next launch, or forgets them when there are none. */
async function save(reporting: Reporting | null) {
  if (reporting === null) {
    await Promise.all(
      [INSTANCE_URL_KEY, DSN_KEY, ENVIRONMENT_KEY].map(key => secureStore.deleteItemAsync(key)),
    );
  } else {
    await Promise.all([
      secureStore.setItemAsync(INSTANCE_URL_KEY, reporting.instanceUrl),
      secureStore.setItemAsync(DSN_KEY, reporting.dsn),
      secureStore.setItemAsync(ENVIRONMENT_KEY, reporting.environment),
    ]);
  }
}

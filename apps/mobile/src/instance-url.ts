/**
 * Finds the Instance at the address the User types, such as `watchclub.example.com`.
 */
import {getInstance, type Instance} from '@watchclub/api';

const ADDRESS = /^(https?:\/\/)?([^\s/?#:]+(?::\d+)?)(\/[^\s?#]*)?$/i;

/** The reason the app can't use the Instance at an address. */
export type InstanceProblem = 'invalidAddress' | 'unreachable' | 'needsSetup';

/** The base URL of the Instance at an address, or the reason the app can't use it. */
type InstanceCheck = {url: string} | {problem: InstanceProblem};

/**
 * Returns the base URL of the Instance at the address the User typed, such as
 * `watchclub.example.com`, or null when it isn't an address. HTTPS unless they typed `http://`.
 */
export function instanceUrl(address: string): string | null {
  const match = ADDRESS.exec(address.trim());
  if (!match) {
    return null;
  }
  const [, scheme = 'https://', host, path = ''] = match;
  // A path stays, for Instances behind a reverse proxy that serves several apps
  return `${scheme.toLowerCase()}${host}${path.replace(/\/+$/, '')}`;
}

/**
 * Returns the base URL of the Instance at the address once a WatchClub that's set up answers there,
 * or the reason the app can't use it.
 */
export async function checkInstance(address: string): Promise<InstanceCheck> {
  const url = instanceUrl(address);
  if (url === null) {
    return {problem: 'invalidAddress'};
  }
  const {data} = await getInstance({baseUrl: url});
  // Nothing when the request fails, and something else when another app answers it
  if (!isInstance(data)) {
    return {problem: 'unreachable'};
  }
  return data.needs_setup ? {problem: 'needsSetup'} : {url};
}

function isInstance(data: unknown): data is Instance {
  return (
    typeof data === 'object' &&
    data !== null &&
    'version' in data &&
    typeof data.version === 'string' &&
    'needs_setup' in data &&
    typeof data.needs_setup === 'boolean'
  );
}

const ADDRESS = /^(https?:\/\/)?([^\s/?#:]+(?::\d+)?)(\/[^\s?#]*)?$/i;

/**
 * Returns the base URL of the server at the address the User typed, such as
 * `watchclub.example.com`, or null when it isn't an address. HTTPS unless they typed `http://`.
 */
export function serverUrl(address: string): string | null {
  const match = ADDRESS.exec(address.trim());
  if (!match) {
    return null;
  }
  const [, scheme = 'https://', host, path = ''] = match;
  // A path stays, for servers behind a reverse proxy that serves several apps
  return `${scheme.toLowerCase()}${host}${path.replace(/\/+$/, '')}`;
}

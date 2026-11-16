/**
 * Returns the address as a path on this site, such as `/settings?tab=1`, or undefined when it
 * leads to another site, so a link can't send Users there.
 */
export function sitePath(address: unknown): string | undefined {
  if (typeof address !== 'string') {
    return undefined;
  }
  // Read as the browser reads it, which ignores tabs and line breaks and takes `\` for `/`
  const url = URL.parse(address, location.origin);
  // A path that starts with `//` leads to the site named after it
  if (url?.origin !== location.origin || url.pathname.startsWith('//')) {
    return undefined;
  }
  return `${url.pathname}${url.search}${url.hash}`;
}

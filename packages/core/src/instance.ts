/**
 * The Instance the app talks to, as its host set it up.
 */
import {useSuspenseQuery} from '@tanstack/react-query';
import {getInstanceOptions} from '@watchclub/api';

/**
 * Returns the Instance Name, which texts such as "On {{name}}" show. Both apps load the Instance
 * before their screens show, so they don't wait for it.
 */
export function useInstanceName(): string {
  const {data: instance} = useSuspenseQuery(getInstanceOptions());
  return instance.name;
}

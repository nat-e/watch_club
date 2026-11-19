/**
 * The Instance the app talks to, as its host set it up.
 */
import {useQuery} from '@tanstack/react-query';
import {getInstanceOptions} from '@watchclub/api';

/**
 * Returns the Instance Name, which texts such as "On {{name}}" show. Until the app loads it, or
 * when it can't, it's the name of the app itself.
 */
export function useInstanceName(): string {
  const {data: instance} = useQuery(getInstanceOptions());
  return instance?.name ?? 'WatchClub';
}

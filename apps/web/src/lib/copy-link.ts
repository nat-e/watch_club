import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';

/**
 * Returns the function that copies a link the User shares, such as an Invitation's, and resolves
 * to whether it did. When the browser doesn't let the page copy, such as on an address without
 * HTTPS, a toast shows the link to copy by hand instead. A link that's still on its way from the
 * API is copied once it arrives; when it doesn't, the function throws why.
 */
export function useCopyLink(): (link: string | Promise<string>) => Promise<boolean> {
  const {t} = useTranslation('web');
  return async link => {
    try {
      // A clipboard item that waits for the link, rather than `writeText` once it arrives, which
      // Safari refuses then: the click that copies it is over
      await navigator.clipboard.write([new ClipboardItem({'text/plain': Promise.resolve(link)})]);
      return true;
    } catch {
      // Throws the API's failure, when it's why the link couldn't be copied
      const text = await link;
      toast.error(
        t($ => $.web.copyLink.failed),
        {
          description: text,
          duration: Number.POSITIVE_INFINITY,
          closeButton: true,
        },
      );
      return false;
    }
  };
}

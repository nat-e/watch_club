import {useMutation} from '@tanstack/react-query';
import {getInstance, type Instance} from '@watchclub/api';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {Text} from 'react-native';
import {Button} from '@/components/button';
import {Screen} from '@/components/screen';
import {TextField} from '@/components/text-field';
import {serverUrl} from '@/server-url';
import {useSession} from '@/session';

/** Why the app can't use the WatchClub at an address. */
class UnusableServer extends Error {
  constructor(readonly problem: 'invalidAddress' | 'unreachable' | 'needsSetup') {
    super(problem);
  }
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

/** Where the User enters the address of their WatchClub, before signing in to it. */
export default function Connect() {
  const {t} = useTranslation('mobile');
  const {connect} = useSession();
  const [address, setAddress] = useState('');
  const check = useMutation({
    mutationFn: async (address: string) => {
      const server = serverUrl(address);
      if (server === null) {
        throw new UnusableServer('invalidAddress');
      }
      const {data} = await getInstance({baseUrl: server});
      // Nothing when the request fails, and something else when another app answers it
      if (!isInstance(data)) {
        throw new UnusableServer('unreachable');
      }
      if (data.needs_setup) {
        throw new UnusableServer('needsSetup');
      }
      await connect(server);
    },
  });

  const problems: Record<UnusableServer['problem'], string> = {
    invalidAddress: t($ => $.mobile.connect.enterAddress),
    unreachable: t($ => $.mobile.connect.unreachable),
    needsSetup: t($ => $.mobile.connect.needsSetup),
  };
  const error = check.error instanceof UnusableServer ? problems[check.error.problem] : undefined;

  return (
    <Screen>
      {/* i18next-instrument-ignore: the name stays the same in every language */}
      <Text accessibilityRole="header" className="text-3xl font-semibold text-foreground">
        WatchClub
      </Text>
      <Text className="text-base text-muted-foreground">
        {t($ => $.mobile.connect.description)}
      </Text>
      <TextField
        label={t($ => $.mobile.connect.address)}
        error={error}
        value={address}
        onChangeText={setAddress}
        onSubmitEditing={() => check.mutate(address)}
        placeholder={t($ => $.mobile.connect.addressPlaceholder)}
        autoCapitalize="none"
        autoCorrect={false}
        autoFocus
        inputMode="url"
        returnKeyType="go"
      />
      <Button disabled={check.isPending} onPress={() => check.mutate(address)}>
        {t($ => $.mobile.connect.submit)}
      </Button>
    </Screen>
  );
}

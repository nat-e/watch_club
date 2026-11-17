const http = require('node:http');
const {getSentryExpoConfig} = require('@sentry/react-native/metro');
const {withUniwindConfig} = require('uniwind/metro');

// Expo's config, with the debug IDs that match Sentry's stack traces to the source maps. Sentry's
// middleware, which shows the source of stack traces in development, would replace the one below
const config = getSentryExpoConfig(__dirname, {enableSourceContextInDevelopment: false});
// The app in development finds the API at the address it loaded from: see `src/session-store.ts`.
// Expo's Metro takes no other middleware, though Metro deprecates this option.
config.server.enhanceMiddleware = metro => (request, response, next) => {
  if (request.url.startsWith('/api/')) {
    forwardApi(request, response);
  } else {
    metro(request, response, next);
  }
};

module.exports = withUniwindConfig(config, {
  cssEntryFile: './src/global.css',
  dtsFile: './src/uniwind-types.d.ts',
});

/** Forwards API calls to the server that `pnpm dev` runs on PORT, as the web app's dev server does. */
function forwardApi(request, response) {
  const forwarded = http.request(
    {
      host: '127.0.0.1',
      port: process.env.PORT,
      method: request.method,
      path: request.url,
      headers: request.headers,
    },
    answer => {
      response.writeHead(answer.statusCode, answer.headers);
      answer.pipe(response);
    },
  );
  forwarded.on('error', () => {
    if (response.headersSent) {
      response.destroy();
    } else {
      response.writeHead(502).end();
    }
  });
  request.pipe(forwarded);
}

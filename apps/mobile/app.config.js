const {execFileSync} = require('node:child_process');

/**
 * Names the app after the worktree's branch, such as "WatchClub (axum)", to tell them apart. Release
 * builds upload their source maps to Sentry when SENTRY_AUTH_TOKEN, SENTRY_ORG and SENTRY_PROJECT
 * are set at prebuild, and skip it otherwise.
 */
module.exports = function appConfig({config}) {
  const branch = currentBranch();
  const sentry = ['@sentry/react-native/expo', {disableAutoUpload: !process.env.SENTRY_AUTH_TOKEN}];
  return {
    ...config,
    name: branch === 'main' || branch === '' ? config.name : `${config.name} (${branch})`,
    plugins: [...config.plugins, sentry],
  };
};

/** Returns the Git branch, or an empty string outside one, such as on a build service. */
function currentBranch() {
  try {
    return execFileSync('git', ['branch', '--show-current'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

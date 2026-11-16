const {execFileSync} = require('node:child_process');

/** Names the app after the worktree's branch, such as "WatchClub (axum)", to tell them apart. */
module.exports = function appConfig({config}) {
  const branch = currentBranch();
  return branch === 'main' || branch === ''
    ? config
    : {...config, name: `${config.name} (${branch})`};
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

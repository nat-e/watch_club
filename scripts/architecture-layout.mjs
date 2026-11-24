// Writes the layouts of the System Context, Container and Component diagrams in docs/architecture,
// aligned on a grid, from the views LikeC4 computes now. LikeC4 uses these saved layouts rather than
// its own, and `pnpm check` fails once a view no longer matches its layout: run it after changing
// what one of these diagrams shows, and give a new element its place here.
import {writeFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {LikeC4} from 'likec4';

const JSON5 = createRequire(import.meta.resolve('likec4'))('json5');
const WIDTH = 320;
const HEIGHT = 180;
const PADDING = 42;
const PADDING_TOP = 60;
const GROUP_GAP = 200;
const ARROWHEAD = 10;

const model = fileURLToPath(new URL('../docs/architecture/', import.meta.url));
const likec4 = await LikeC4.fromWorkspace(model, {logger: false});
const views = (await likec4.layoutedModel()).$data.views;
await likec4.dispose();

writeLayout(views.index, systemContext());
writeLayout(views.containers, containers());
writeLayout(views.server, serverComponents());

/** The boxes of a group of external systems, in one column, or two with `second` */
function group(x, rows, first, second = []) {
  const children = {};
  first.forEach((id, row) => {
    children[id] = box(x + PADDING, rows[row]);
  });
  second.forEach((id, row) => {
    if (id) {
      children[id] = box(x + PADDING + WIDTH + 40, rows[row]);
    }
  });
  const columns = second.length ? 2 : 1;
  const width = columns * WIDTH + (columns - 1) * 40 + 2 * PADDING;
  return {children, bounds: frame(x, rows, width)};
}

function box(x, y, width = WIDTH, height = HEIGHT) {
  return {x, y, width, height};
}

/** A group's or a system's frame around rows of boxes */
function frame(x, rows, width) {
  const y = rows[0] - PADDING_TOP;
  return {x, y, width, height: rows.at(-1) + HEIGHT + PADDING - y};
}

function systemContext() {
  const rows = [160, 380, 600];
  const providers = group(-PADDING, rows, [
    'metadataProviders.tmdb',
    'metadataProviders.hardcover',
    'metadataProviders.sportarr',
  ]);
  const right = b => b.x + b.width;
  const watchclub = box(right(providers.bounds) + GROUP_GAP, rows[1]);
  const centerX = watchclub.x + WIDTH / 2;
  // The people above, side by side between the groups
  const user = box(centerX - WIDTH - 40, providers.bounds.y - 120 - HEIGHT);
  const administrator = box(centerX + 40, user.y);
  const bottom = providers.bounds.y + providers.bounds.height;
  const observability = box(centerX - 120, bottom - 135, 240, 135);
  const sources = group(
    right(watchclub) + GROUP_GAP,
    rows,
    ['externalSources.radarr', 'externalSources.sonarr', 'externalSources.sportarr'],
    [null, 'externalSources.filesystem'],
  );
  const middle = watchclub.y + HEIGHT / 2;

  return {
    nodes: {
      user,
      administrator,
      watchclub,
      observability,
      metadataProviders: providers.bounds,
      ...providers.children,
      externalSources: sources.bounds,
      ...sources.children,
    },
    arrows: {
      'user->watchclub': arrow(
        [user.x + WIDTH / 2, user.y + HEIGHT],
        [watchclub.x + 80, watchclub.y],
        'left',
      ),
      'administrator->watchclub': arrow(
        [administrator.x + WIDTH / 2, administrator.y + HEIGHT],
        [right(watchclub) - 80, watchclub.y],
        'right',
      ),
      'watchclub->observability': arrow(
        [centerX, watchclub.y + HEIGHT],
        [centerX, observability.y],
        'right',
      ),
      'watchclub->metadataProviders': arrow(
        [watchclub.x, middle],
        [right(providers.bounds), middle],
        'above',
      ),
      'watchclub->externalSources': arrow(
        [right(watchclub), middle],
        [sources.bounds.x, middle],
        'above',
      ),
    },
  };
}

function containers() {
  const rows = [160, 440, 720];
  const providers = group(-PADDING, rows, [
    'metadataProviders.tmdb',
    'metadataProviders.hardcover',
    'metadataProviders.sportarr',
  ]);
  const right = b => b.x + b.width;

  // WatchClub: the clients in a row, with the Chromecast receiver in the middle between the apps that
  // cast to it, the server below it, and the database below the web app
  const clientsGap = 120;
  const frameX = right(providers.bounds) + GROUP_GAP;
  const left = frameX + PADDING;
  const web = box(left, rows[0]);
  const castReceiver = box(left + WIDTH + clientsGap, rows[0]);
  const mobile = box(left + 2 * (WIDTH + clientsGap), rows[0]);
  const centerX = castReceiver.x + WIDTH / 2;
  const server = box(castReceiver.x, rows[1]);
  const database = box(left, rows[2]);
  const watchclub = frame(frameX, rows, 3 * WIDTH + 2 * clientsGap + 2 * PADDING);

  const user = box(server.x, watchclub.y - 160 - HEIGHT);
  const administrator = box(web.x, user.y);
  const bottom = watchclub.y + watchclub.height;
  const observability = box(centerX - 120, bottom + 120, 240, 135);
  const sources = group(
    right(watchclub) + GROUP_GAP,
    rows,
    ['externalSources.radarr', 'externalSources.sonarr', 'externalSources.sportarr'],
    [null, 'externalSources.filesystem'],
  );
  const middle = server.y + HEIGHT / 2;
  const clientsMiddle = castReceiver.y + HEIGHT / 2;
  const center = b => b.x + WIDTH / 2;

  return {
    nodes: {
      user,
      administrator,
      observability,
      watchclub,
      'watchclub.web': web,
      'watchclub.mobile': mobile,
      'watchclub.castReceiver': castReceiver,
      'watchclub.server': server,
      'watchclub.database': database,
      metadataProviders: providers.bounds,
      ...providers.children,
      externalSources: sources.bounds,
      ...sources.children,
    },
    arrows: {
      'user->watchclub.web': arrow([user.x + 64, user.y + HEIGHT], [center(web), web.y], 'left'),
      'administrator->watchclub.web': arrow(
        [web.x + 80, administrator.y + HEIGHT],
        [web.x + 80, web.y],
        'left',
      ),
      'user->watchclub.castReceiver': arrow(
        [centerX, user.y + HEIGHT],
        [centerX, castReceiver.y],
        'right',
      ),
      'user->watchclub.mobile': arrow(
        [right(user) - 64, user.y + HEIGHT],
        [center(mobile), mobile.y],
        'right',
      ),
      'watchclub.web->watchclub.castReceiver': arrow(
        [right(web), clientsMiddle],
        [castReceiver.x, clientsMiddle],
        'above',
      ),
      'watchclub.mobile->watchclub.castReceiver': arrow(
        [mobile.x, clientsMiddle],
        [right(castReceiver), clientsMiddle],
        'above',
      ),
      'watchclub.web->watchclub.server': arrow(
        [center(web), web.y + HEIGHT],
        [server.x + 64, server.y],
        'left',
      ),
      'watchclub.castReceiver->watchclub.server': arrow(
        [centerX, castReceiver.y + HEIGHT],
        [centerX, server.y],
        'right',
      ),
      'watchclub.mobile->watchclub.server': arrow(
        [center(mobile), mobile.y + HEIGHT],
        [right(server) - 64, server.y],
        'right',
      ),
      'watchclub.server->watchclub.database': arrow(
        [server.x + 64, server.y + HEIGHT],
        [right(database) - 64, database.y],
        'left',
      ),
      'watchclub.server->observability': arrow(
        [centerX, server.y + HEIGHT],
        [centerX, observability.y],
        'right',
      ),
      'watchclub.server->metadataProviders': arrow(
        [server.x, middle],
        [right(providers.bounds), middle],
        'above',
        {between: [right(providers.bounds), frameX]},
      ),
      'watchclub.server->externalSources': arrow(
        [right(server), middle],
        [sources.bounds.x, middle],
        'above',
        {between: [right(watchclub), sources.bounds.x]},
      ),
    },
  };
}

function serverComponents() {
  const right = b => b.x + b.width;
  const center = b => b.x + WIDTH / 2;
  const bottom = b => b.y + b.height;

  // The server: its entry points on top, the jobs above Contents which they refresh and the API in
  // the middle, and the domains below them in their own box
  const columnsGap = 120;
  const entryRow = 160;
  const domainsFrameY = entryRow + HEIGHT + 120;
  const domainsRow = domainsFrameY + PADDING_TOP;
  const groupRows = [domainsRow - HEIGHT - 40, domainsRow, domainsRow + HEIGHT + 40];
  const providers = group(-PADDING, groupRows, [
    'metadataProviders.tmdb',
    'metadataProviders.hardcover',
    'metadataProviders.sportarr',
  ]);
  const serverX = right(providers.bounds) + GROUP_GAP;
  const domainsFrameX = serverX + PADDING;
  const column = i => domainsFrameX + PADDING + i * (WIDTH + columnsGap);
  const [contents, accounts, conversations, serverSources] = [0, 1, 2, 3].map(i =>
    box(column(i), domainsRow),
  );
  const domains = {
    x: domainsFrameX,
    y: domainsFrameY,
    width: 4 * WIDTH + 3 * columnsGap + 2 * PADDING,
    height: domainsRow + HEIGHT + PADDING - domainsFrameY,
  };
  const jobs = box(contents.x, entryRow);
  const api = box(domains.x + domains.width / 2 - WIDTH / 2, entryRow);
  const server = {
    x: serverX,
    y: entryRow - PADDING_TOP,
    width: domains.width + 2 * PADDING,
    height: bottom(domains) + PADDING - (entryRow - PADDING_TOP),
  };

  // The clients above, as in the Containers view, and the database below
  const clientsGap = 120;
  const castReceiver = box(api.x, server.y - 160 - HEIGHT);
  const web = box(api.x - WIDTH - clientsGap, castReceiver.y);
  const mobile = box(api.x + WIDTH + clientsGap, castReceiver.y);
  const database = box(api.x, bottom(server) + 160);
  const sources = group(
    right(server) + GROUP_GAP,
    groupRows,
    ['externalSources.radarr', 'externalSources.sonarr', 'externalSources.sportarr'],
    [null, 'externalSources.filesystem'],
  );
  const domainsMiddle = domainsRow + HEIGHT / 2;
  const betweenColumns = right(contents) + columnsGap / 2;

  return {
    nodes: {
      'watchclub.web': web,
      'watchclub.castReceiver': castReceiver,
      'watchclub.mobile': mobile,
      'watchclub.server': server,
      'watchclub.server.api': api,
      'watchclub.server.jobs': jobs,
      'watchclub.server.domains': domains,
      'watchclub.server.domains.contents': contents,
      'watchclub.server.domains.accounts': accounts,
      'watchclub.server.domains.conversations': conversations,
      'watchclub.server.domains.sources': serverSources,
      'watchclub.database': database,
      metadataProviders: providers.bounds,
      ...providers.children,
      externalSources: sources.bounds,
      ...sources.children,
    },
    arrows: {
      'watchclub.web->watchclub.server.api': arrow(
        [center(web), bottom(web)],
        [api.x + 64, api.y],
        'left',
      ),
      'watchclub.castReceiver->watchclub.server.api': arrow(
        [center(castReceiver), bottom(castReceiver)],
        [center(api), api.y],
        'right',
      ),
      'watchclub.mobile->watchclub.server.api': arrow(
        [center(mobile), bottom(mobile)],
        [right(api) - 64, api.y],
        'right',
      ),
      'watchclub.server.api->watchclub.server.domains': arrow(
        [center(api), bottom(api)],
        [center(api), domains.y],
        'right',
      ),
      'watchclub.server.jobs->watchclub.server.domains': arrow(
        [center(jobs), bottom(jobs)],
        [center(jobs), domains.y],
        'right',
      ),
      'watchclub.server.domains.contents->watchclub.server.jobs': arrow(
        [contents.x + 60, contents.y],
        [jobs.x + 60, bottom(jobs)],
        'left',
      ),
      // Between Contents and Accounts, then beside the database, which the other arrows don't reach
      'watchclub.server.jobs->watchclub.database': route(
        [
          [right(jobs), jobs.y + HEIGHT / 2],
          [betweenColumns, jobs.y + HEIGHT / 2],
          [betweenColumns, database.y + HEIGHT / 2],
          [database.x, database.y + HEIGHT / 2],
        ],
        'above',
        {segment: 2},
      ),
      'watchclub.server.domains->watchclub.database': arrow(
        [center(api), bottom(domains)],
        [center(api), database.y],
        'right',
      ),
      'watchclub.server.domains.contents->metadataProviders': arrow(
        [contents.x, domainsMiddle],
        [right(providers.bounds), domainsMiddle],
        'above',
        {between: [right(providers.bounds), serverX]},
      ),
      'watchclub.server.domains.sources->externalSources': arrow(
        [right(serverSources), domainsMiddle],
        [sources.bounds.x, domainsMiddle],
        'above',
        {between: [right(server), sources.bounds.x]},
      ),
    },
  };
}

/**
 * A straight arrow, which stops short of its target for the arrowhead. Its label goes beside it, at
 * `at` of its length, or above it, centered between `between`'s two x when given.
 */
function arrow(from, to, side, options) {
  return route([from, to], side, options);
}

/**
 * An arrow along straight segments through `corners`, which stops short of its target for the
 * arrowhead. Its label goes beside its segment number `segment`, as `arrow` places it.
 */
function route(corners, side, {segment = 0, between, at = 0.5} = {}) {
  const [last, target] = corners.slice(-2);
  const length = Math.hypot(target[0] - last[0], target[1] - last[1]);
  const end = [
    target[0] - ((target[0] - last[0]) * ARROWHEAD) / length,
    target[1] - ((target[1] - last[1]) * ARROWHEAD) / length,
  ];
  const ends = [...corners.slice(0, -1), end];
  const points = [ends[0]];
  for (let i = 1; i < ends.length; i++) {
    const [a, b] = [ends[i - 1], ends[i]];
    for (const t of [1, 2, 3]) {
      points.push([a[0] + ((b[0] - a[0]) * t) / 3, a[1] + ((b[1] - a[1]) * t) / 3]);
    }
  }
  return {
    points: points.map(([x, y]) => [Math.round(x), Math.round(y)]),
    side,
    between,
    at,
    labelSegment: [ends[segment], ends[segment + 1]],
  };
}

function writeLayout(view, {nodes, arrows}) {
  view = structuredClone(view);

  for (const node of view.nodes) {
    if (!nodes[node.id]) {
      throw new Error(`${view.id}: no position for ${node.id}`);
    }
    Object.assign(node, nodes[node.id]);
  }

  for (const edge of view.edges) {
    const arrow = arrows[`${edge.source}->${edge.target}`];
    if (!arrow) {
      throw new Error(`${view.id}: no arrow for ${edge.source}->${edge.target}`);
    }
    edge.points = arrow.points;
    edge.controlPoints = null;
    const [start, end] = arrow.labelSegment;
    const middle = [
      start[0] + (end[0] - start[0]) * arrow.at,
      start[1] + (end[1] - start[1]) * arrow.at,
    ];
    const {width, height} = edge.labelBBox;
    const top = middle[1] - height / 2;
    // Where the arrow is at the label's top and bottom, so that a slanted arrow misses the label
    const xAt = y =>
      end[1] === start[1]
        ? middle[0]
        : start[0] + ((end[0] - start[0]) * (y - start[1])) / (end[1] - start[1]);
    const reach = [xAt(top), xAt(top + height)];
    const centerX = arrow.between ? (arrow.between[0] + arrow.between[1]) / 2 : middle[0];
    const position = {
      right: {x: Math.max(...reach) + 10, y: top},
      left: {x: Math.min(...reach) - 10 - width, y: top},
      above: {x: centerX - width / 2, y: middle[1] - height - 8},
      below: {x: centerX - width / 2, y: middle[1] + 8},
    }[arrow.side];
    edge.labelBBox = {x: Math.round(position.x), y: Math.round(position.y), width, height};
  }

  // Around every box, label and arrow
  const boxes = [...view.nodes, ...view.edges.map(e => e.labelBBox)];
  const points = view.edges.flatMap(e => e.points);
  const minX = Math.min(...boxes.map(n => n.x), ...points.map(([x]) => x));
  const minY = Math.min(...boxes.map(n => n.y), ...points.map(([, y]) => y));
  const maxX = Math.max(...boxes.map(n => n.x + n.width), ...points.map(([x]) => x));
  const maxY = Math.max(...boxes.map(n => n.y + n.height), ...points.map(([, y]) => y));
  view.bounds = {x: minX - 20, y: minY - 20, width: maxX - minX + 40, height: maxY - minY + 40};
  view._layout = 'manual';

  writeFileSync(`${model}.likec4/${view.id}.likec4.snap`, `${JSON5.stringify(view, null, 2)}\n`);
}

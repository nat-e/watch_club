# syntax=docker/dockerfile:1
# The image self-hosters run: the server, with the web app built into it.

ARG NODE_VERSION=26.12.1
ARG RUST_VERSION=1.99.1
ARG DEBIAN_VERSION=trixie

# The web app, built from the workspace packages it uses
FROM node:${NODE_VERSION}-${DEBIAN_VERSION}-slim AS web
RUN npm install --global pnpm@11.12.0
WORKDIR /app
# The manifests first, so code changes don't reinstall the dependencies
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/web/package.json apps/web/
COPY packages/api/package.json packages/api/
COPY packages/core/package.json packages/core/
RUN pnpm install --frozen-lockfile --filter web...
COPY tsconfig.base.json ./
COPY packages packages
COPY apps/web apps/web
RUN pnpm --filter @watchclub/api generate:client && pnpm --filter web build

# The server, which embeds the web app
FROM rust:${RUST_VERSION}-slim-${DEBIAN_VERSION} AS server
WORKDIR /app/apps/server
COPY apps/server ./
COPY --from=web /app/apps/web/dist /app/apps/web/dist
# The SQLx macros check queries against .sqlx, as no database runs here
ENV SQLX_OFFLINE=true
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/apps/server/target,sharing=locked \
    cargo build --release --locked --bin watch_club \
    && cp target/release/watch_club /usr/local/bin/

FROM debian:${DEBIAN_VERSION}-slim
# tini reaps the processes the server starts
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl tini \
    && rm -rf /var/lib/apt/lists/*
COPY --from=server /usr/local/bin/watch_club /usr/local/bin/
USER nobody
ENV PORT=4000
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --start-interval=2s \
    CMD curl --fail --silent "http://localhost:${PORT}/api/health" || exit 1
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["watch_club"]

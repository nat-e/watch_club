# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=trixie-20261020-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.20.4-erlang-29.1.2-debian-trixie-20261020-slim
#
# renovate: datasource=hexpm-bob depName=elixir
ARG ELIXIR_VERSION=1.20.4
# renovate: datasource=github-tags depName=erlang packageName=erlang/otp versioning=regex:^(?<major>\d+?)\.(?<minor>\d+?)(\.(?<patch>\d+))?$ extractVersion=^OTP-(?<version>\S+)
ARG OTP_VERSION=29.1.2
# renovate: datasource=docker depName=debian versioning=regex:^trixie-(?<patch>\d{8})-slim$
ARG DEBIAN_VERSION=trixie-20261020-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies. Node.js + npm are needed to install the JS
# dependencies (Video.js, sortablejs) that esbuild bundles.
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git nodejs npm \
  && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy the JS manifests first so `mix assets.setup` (which runs
# `npm install --prefix assets`) can install into assets/node_modules. This
# layer is cached until package.json/package-lock.json change. node_modules is
# excluded via .dockerignore, so the later `COPY assets assets` won't clobber it.
COPY assets/package.json assets/package-lock.json assets/
RUN mix assets.setup

COPY priv priv

COPY lib lib

# Compile the release
RUN mix compile

# Bundles the source code into the release so Sentry can show it around errors
RUN mix sentry.package_source_code

COPY assets assets

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

# renovate: datasource=deb depName=ffmpeg
ARG FFMPEG_VERSION=7:7.1.5-0+deb13u1
# fpcalc, which fingerprints audio to find the Markers of Videos
# renovate: datasource=deb depName=libchromaprint-tools
ARG CHROMAPRINT_VERSION=1.5.1-7

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  libstdc++6 openssl libncurses6 locales ca-certificates tini curl \
  ffmpeg=${FFMPEG_VERSION} \
  libchromaprint-tools=${CHROMAPRINT_VERSION} \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Persistent data dir (trickplay sprite sheets, etc.). Created and owned by
# nobody here so a fresh named volume mounted over it inherits that ownership.
RUN mkdir -p /data/trickplay && chown -R nobody:root /data

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/watch_club ./

USER nobody

# Lets `docker compose up --wait` and orchestrators know when the app is ready
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --start-interval=2s \
  CMD curl -fsS "http://localhost:${WC_PORT:-4000}/health" > /dev/null || exit 1

# Using tini as an entrypoint to avoid zombie ffmpeg processes
# See https://github.com/krallin/tini for details
ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/app/bin/docker-entrypoint"]

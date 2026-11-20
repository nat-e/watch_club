# WatchClub

A self-hosted media server for small private groups.

> [!WARNING]
> This branch rewrites WatchClub with an axum server in Rust, a React web app and an Expo app for phones and TVs. It doesn't do what the released app does yet: install the released app from [`main`](https://github.com/nat-e/watch_club/tree/main).

## Try the rewrite

Every change to this branch publishes the image `ghcr.io/nat-e/watch_club:rust`. It listens on port 4000 and needs:

- A Postgres database, whose URL goes in `DATABASE_URL`
- A [TMDB](https://www.themoviedb.org) account, where WatchClub finds movies and TV shows. Its API Read Access Token, from [your API settings](https://www.themoviedb.org/settings/api), goes in `TMDB_API_TOKEN`
- A [Hardcover](https://hardcover.app) account, where WatchClub finds books. Its API token, from [your API settings](https://hardcover.app/account/api), goes in `HARDCOVER_API_TOKEN`

It finds sports events on [sportarr.net](https://sportarr.net), which needs no account.

```sh
docker run --detach --publish 4000:4000 \
  --env DATABASE_URL=postgres://user:password@host:5432/watch_club \
  --env TMDB_API_TOKEN=your-token \
  --env HARDCOVER_API_TOKEN=your-token \
  ghcr.io/nat-e/watch_club:rust
```

Database migrations run on start.

WatchClub encrypts the secrets it stores, such as the API keys of Radarr, Sonarr and Sportarr. By default, it uses a key written in its code, so anyone with a copy of the database can read them. To protect them, generate your own key with `openssl rand -base64 32` and put it in `ENCRYPTION_KEY`. When you set or change the key, enter the API keys again.

To see what the server is doing, through its logs, OpenTelemetry or Sentry, read [docs/observability.md](docs/observability.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)

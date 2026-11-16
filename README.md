# WatchClub

A self-hosted media server for small private groups.

> [!WARNING]
> This branch rewrites WatchClub with an axum server in Rust, a React web app and an Expo app for phones and TVs. It doesn't do what the released app does yet: install the released app from [`main`](https://github.com/nat-e/watch_club/tree/main).

## Try the rewrite

Every change to this branch publishes the image `ghcr.io/nat-e/watch_club:rust`. It listens on port 4000 and needs a Postgres database, whose URL goes in `DATABASE_URL`:

```sh
docker run --detach --publish 4000:4000 \
  --env DATABASE_URL=postgres://user:password@host:5432/watch_club \
  ghcr.io/nat-e/watch_club:rust
```

Database migrations run on start.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)

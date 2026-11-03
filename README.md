# WatchClub

A self-hosted media server for small private groups.

> [!WARNING]
> WatchClub is in early development (alpha). Expect bugs and breaking changes between releases until 1.0.

## Install

1. Copy [`docker-compose.yml`](docker-compose.yml) and [`.env.example`](.env.example) to a folder on your server, and rename `.env.example` to `.env`.
2. Fill in `.env`, and mount your media folders in `docker-compose.yml`.
3. Run `docker compose up -d`, then open `WC_URL` to create the administrator account.

To upgrade, run `docker compose pull && docker compose up -d`. Database migrations run on start.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)

//! Prints the OpenAPI document of the API, which `packages/api` generates its client from.

fn main() -> anyhow::Result<()> {
    println!("{}", watch_club::openapi::document().to_pretty_json()?);
    Ok(())
}

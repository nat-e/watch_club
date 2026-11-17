//! Fills an empty database with demo Users to try the app with. Only for development: run it with
//! `pnpm --filter server seed`.

use anyhow::Context;
use secrecy::ExposeSecret;
use watch_club::{config, db, domain::accounts::Locale};

/// Every demo User's password
const PASSWORD: &str = "passw0rd";

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let url = config::database_url()?;
    let db = db::connect(url.expose_secret()).await?;

    let has_users = sqlx::query_scalar!(r#"SELECT EXISTS (SELECT FROM users) AS "exists!""#)
        .fetch_one(&db)
        .await?;
    if has_users {
        println!("The database already has Users, so it wasn't seeded");
        return Ok(());
    }

    let password_hash = password_auth::generate_hash(PASSWORD);
    // All or none, so a failed run leaves the database empty for the next one
    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    for (username, locale, is_instance_administrator) in [
        ("admin", Locale::EnUs, true),
        ("alice", Locale::EnUs, false),
        ("bob", Locale::FrFr, false),
    ] {
        sqlx::query!(
            r#"
            INSERT INTO users (username, password_hash, locale, is_instance_administrator)
            VALUES ($1, $2, $3, $4)
            "#,
            username,
            password_hash,
            locale as Locale,
            is_instance_administrator,
        )
        .execute(&mut transaction)
        .await
        .with_context(|| format!("failed to create {username}"))?;
    }
    transaction
        .commit()
        .await
        .context("failed to save the demo Users")?;

    println!("Seeded. Sign in as admin, alice or bob with the password \"{PASSWORD}\"");
    Ok(())
}

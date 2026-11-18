//! Fills an empty database with the Instance Administrator, to try the app with. Only for
//! development: run it with `pnpm --filter server seed`.

use secrecy::ExposeSecret;
use watch_club::{
    config, db,
    domain::accounts::{self, CreateInstanceAdministratorError, Locale, Password, Username},
};

/// The Instance Administrator's username
const USERNAME: &str = "admin";
/// The Instance Administrator's password
const PASSWORD: &str = "passw0rd";

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let url = config::database_url()?;
    let db = db::connect(url.expose_secret()).await?;

    let username = Username::parse(USERNAME).expect("the seed's username follows the rules");
    let password = Password::parse(PASSWORD.into()).expect("the seed's password follows the rules");
    // Signs them in too, on a device nobody uses
    match accounts::create_instance_administrator(&db, username, password, Locale::EnUs).await {
        Ok(_) => println!("Seeded. Sign in as {USERNAME} with the password \"{PASSWORD}\""),
        Err(CreateInstanceAdministratorError::AlreadyExists) => {
            println!("The database already has its Instance Administrator, so it wasn't seeded");
        }
        Err(error) => return Err(error.into()),
    }
    Ok(())
}

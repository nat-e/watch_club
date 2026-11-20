//! The encryption of the secrets that WatchClub stores, through `utils::encryption::EncryptionKey`.

use secrecy::{ExposeSecret, SecretString};
use watch_club::utils::encryption::EncryptionKey;

use crate::support::{self, ENCRYPTION_KEY};

const API_KEY: &str = "radarr-api-key";

#[test]
fn decrypts_what_it_encrypted() {
    let encrypted = support::encryption_key().encrypt(&API_KEY.into());

    let decrypted = support::encryption_key().decrypt(&encrypted).unwrap();

    assert_eq!(decrypted.expose_secret(), API_KEY);
}

#[test]
fn encrypts_a_secret_differently_each_time() {
    let secret = SecretString::from(API_KEY);
    let key = support::encryption_key();

    assert_ne!(key.encrypt(&secret), key.encrypt(&secret));
}

#[test]
fn fails_to_decrypt_with_another_key() {
    let encrypted = support::encryption_key().encrypt(&API_KEY.into());

    assert!(
        support::another_encryption_key()
            .decrypt(&encrypted)
            .is_err()
    );
}

#[test]
fn decrypts_with_the_built_in_key_what_it_encrypted() {
    let encrypted = EncryptionKey::built_in().encrypt(&API_KEY.into());

    let decrypted = EncryptionKey::built_in().decrypt(&encrypted).unwrap();

    assert_eq!(decrypted.expose_secret(), API_KEY);
}

#[test]
fn reads_only_32_bytes_in_base64() {
    let not_base64 = EncryptionKey::from_base64("not base64!");
    let too_short = EncryptionKey::from_base64("c2hvcnQ=");

    assert!(not_base64.is_err());
    assert!(
        format!("{:#}", too_short.unwrap_err()).contains("openssl rand -base64 32"),
        "the error tells the host how to make a key"
    );
}

#[test]
fn reads_a_key_with_spaces_around_it() {
    assert!(EncryptionKey::from_base64(&format!(" {ENCRYPTION_KEY}\n")).is_ok());
}

#[test]
fn leaves_the_key_and_the_encrypted_bytes_out_of_debug_output() {
    let key = support::encryption_key();
    let encrypted = key.encrypt(&API_KEY.into());

    assert_eq!(format!("{key:?}"), "EncryptionKey(..)");
    assert_eq!(format!("{encrypted:?}"), "EncryptedSecret(..)");
}

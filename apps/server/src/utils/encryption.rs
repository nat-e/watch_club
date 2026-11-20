//! The encryption of the secrets that WatchClub stores, such as the API keys of Sources, in
//! AES-256-GCM: with the host's `ENCRYPTION_KEY`, or with the key built into WatchClub.

use std::fmt::{self, Debug, Formatter};

use aes_gcm::{
    Aes256Gcm, Nonce,
    aead::{Aead, Generate, KeyInit},
};
use anyhow::Context;
use base64::{Engine, engine::general_purpose::STANDARD};
use secrecy::{ExposeSecret, SecretString};

/// The length of a nonce, which starts each encrypted secret
const NONCE_LENGTH: usize = 12;

/// The key of hosts that set no `ENCRYPTION_KEY`. It's public, as it's in this code: it hides the
/// secrets from people who see the database by chance, not from anyone who has a copy of it.
// Changing it loses the secrets that hosts without an `ENCRYPTION_KEY` stored
const BUILT_IN_KEY: &str = "ImqAxtEpdNOQ9tyIXAbTEJ9Fe4De6hKFSOh2gaAyuY4=";

/// The key that WatchClub encrypts the secrets it stores with. Losing it loses them.
#[derive(Clone)]
pub struct EncryptionKey(Aes256Gcm);

/// A secret that `EncryptionKey::encrypt` encrypted, as WatchClub stores it: only `decrypt` with
/// the same key reads it.
// Its bytes are a random nonce, then the ciphertext with its tag
#[derive(Clone, PartialEq, Eq, sqlx::Type)]
#[sqlx(transparent)]
pub struct EncryptedSecret(Vec<u8>);

/// The failure to decrypt a secret, which another key encrypted, or whose bytes changed since.
#[derive(Debug, thiserror::Error)]
#[error(
    "failed to decrypt a secret: another key encrypted it, before ENCRYPTION_KEY was set or changed"
)]
pub struct DecryptionError;

impl EncryptionKey {
    /// Returns the key built into WatchClub, for hosts that set no `ENCRYPTION_KEY`.
    pub fn built_in() -> Self {
        Self::from_base64(BUILT_IN_KEY).expect("the built-in key is 32 bytes in base64")
    }

    /// Reads the key from its 32 bytes in base64, such as `openssl rand -base64 32` prints. The
    /// error says so, for the host.
    pub fn from_base64(text: &str) -> anyhow::Result<Self> {
        let bytes = STANDARD.decode(text.trim()).ok();
        let cipher = bytes.and_then(|bytes| Aes256Gcm::new_from_slice(&bytes).ok());
        cipher
            .map(Self)
            .context("it must be 32 bytes in base64, such as `openssl rand -base64 32` prints")
    }

    /// Returns the secret encrypted, differently each time.
    pub fn encrypt(&self, secret: &SecretString) -> EncryptedSecret {
        let nonce = Nonce::generate();
        let ciphertext = self
            .0
            .encrypt(&nonce, secret.expose_secret().as_bytes())
            .expect("a secret is shorter than the 64 GB that AES-GCM encrypts at once");
        EncryptedSecret([nonce.as_slice(), &ciphertext].concat())
    }

    /// Returns the secret that `encrypt` encrypted with this key.
    pub fn decrypt(&self, encrypted: &EncryptedSecret) -> Result<SecretString, DecryptionError> {
        let (nonce, ciphertext) = encrypted
            .0
            .split_at_checked(NONCE_LENGTH)
            .ok_or(DecryptionError)?;
        let nonce = Nonce::try_from(nonce).expect("the nonce has the length that AES-GCM takes");
        let secret = self
            .0
            .decrypt(&nonce, ciphertext)
            .map_err(|_| DecryptionError)?;

        // `encrypt` only takes text, and the tag proves this key encrypted it
        let secret = String::from_utf8(secret).map_err(|_| DecryptionError)?;
        Ok(secret.into())
    }
}

/// Leaves the key out, so that it can't reach logs.
impl Debug for EncryptionKey {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str("EncryptionKey(..)")
    }
}

/// Leaves the bytes out, which only add noise to logs.
impl Debug for EncryptedSecret {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str("EncryptedSecret(..)")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const KEY: &str = "q5OMH0wWDIQnaWrTU+zAPahOTWVdTpqo8uUpKzVZ1Ag=";
    const API_KEY: &str = "radarr-api-key";

    fn key() -> EncryptionKey {
        EncryptionKey::from_base64(KEY).unwrap()
    }

    #[test]
    fn hides_the_secret() {
        let encrypted = key().encrypt(&API_KEY.into());

        let has_secret = encrypted
            .0
            .windows(API_KEY.len())
            .any(|window| window == API_KEY.as_bytes());
        assert!(!has_secret);
    }

    #[test]
    fn fails_to_decrypt_changed_or_cut_bytes() {
        let encrypted = key().encrypt(&API_KEY.into());
        let mut changed = encrypted.clone();
        *changed.0.last_mut().unwrap() ^= 1;
        let cut = EncryptedSecret(encrypted.0[..5].to_vec());
        let empty = EncryptedSecret(Vec::new());

        assert!(key().decrypt(&changed).is_err());
        assert!(key().decrypt(&cut).is_err());
        assert!(key().decrypt(&empty).is_err());
    }
}

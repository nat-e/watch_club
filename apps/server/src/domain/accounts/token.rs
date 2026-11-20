//! The random secrets that sign Users in or let them choose a new password: the session tokens and
//! the tokens of Password Reset Links.

use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use secrecy::{ExposeSecret, ExposeSecretMut, SecretBox};
use sha2::{Digest, Sha256};

/// A secret of 32 random bytes, which nobody can guess. The database only stores its hash, so a
/// leaked database gives the secrets to nobody.
#[derive(Debug)]
pub(super) struct SecretToken(SecretBox<[u8; 32]>);

impl SecretToken {
    pub(super) fn random() -> Result<Self, getrandom::Error> {
        let mut bytes = SecretBox::<[u8; 32]>::default();
        getrandom::fill(bytes.expose_secret_mut())?;
        Ok(Self(bytes))
    }

    /// Reads a token in the form [`encode`](Self::encode) gives, or returns None.
    pub(super) fn decode(text: &str) -> Option<Self> {
        let mut bytes = SecretBox::<[u8; 32]>::default();
        let length = URL_SAFE_NO_PAD
            .decode_slice(text, bytes.expose_secret_mut())
            .ok()?;
        (length == bytes.expose_secret().len()).then_some(Self(bytes))
    }

    /// Returns the token as text that fits in a cookie, a header or a link.
    pub(super) fn encode(&self) -> String {
        URL_SAFE_NO_PAD.encode(self.0.expose_secret())
    }

    /// Returns the hash the database stores and finds the token by.
    pub(super) fn hash(&self) -> [u8; 32] {
        Sha256::digest(self.0.expose_secret()).into()
    }
}

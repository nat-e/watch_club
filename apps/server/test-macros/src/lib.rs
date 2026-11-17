//! The attribute macros of the server's tests, which Rust only allows in a crate of their own.

use proc_macro::TokenStream;
use quote::quote;
use syn::{Error, FnArg, ItemFn, parse::Nothing, parse_macro_input, parse_quote};

/// Runs an `async fn` integration test whose only argument is a pool on a database of its own, such
/// as `async fn signs_in(db: PgPool)`, from `support::TestDatabase`, which it drops after the test.
#[proc_macro_attribute]
pub fn database_test(args: TokenStream, item: TokenStream) -> TokenStream {
    parse_macro_input!(args as Nothing);
    let mut test = parse_macro_input!(item as ItemFn);

    let mut inputs = std::mem::take(&mut test.sig.inputs).into_iter();
    let (Some(FnArg::Typed(db)), None) = (inputs.next(), inputs.next()) else {
        return Error::new_spanned(
            &test.sig,
            "a #[database_test] takes its database as its only argument, such as `db: PgPool`",
        )
        .to_compile_error()
        .into();
    };
    let body = &test.block;
    test.block = parse_quote!({
        let database = crate::support::TestDatabase::create().await;
        let #db = database.pool();
        // Catches the test's panic, so that a failed test drops its database too
        let outcome = ::futures_util::FutureExt::catch_unwind(::std::panic::AssertUnwindSafe(
            async move #body,
        ))
        .await;
        database.drop().await;
        match outcome {
            Ok(output) => output,
            Err(panic) => ::std::panic::resume_unwind(panic),
        }
    });
    quote!(#[::tokio::test] #test).into()
}

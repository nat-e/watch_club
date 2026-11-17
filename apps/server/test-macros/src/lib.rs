//! The attribute macros of the server's tests, which Rust only allows in a crate of their own.

use proc_macro::TokenStream;
use quote::quote;
use syn::{Error, FnArg, ItemFn, parse::Nothing, parse_macro_input, parse_quote};

/// Runs an `async fn` test whose only argument is a pool on a database of its own, such as
/// `async fn signs_in(db: PgPool)`, from `watch_club::testing::database`.
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
        let #db = ::watch_club::testing::database().await;
        #body
    });
    quote!(#[::tokio::test] #test).into()
}

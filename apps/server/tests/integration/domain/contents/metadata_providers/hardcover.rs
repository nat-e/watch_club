use std::num::NonZeroU32;

use jiff::civil::date;
use secrecy::SecretString;
use serde_json::{Value, json};
use watch_club::domain::contents::{
    CreditKind, ExternalContentId, Hardcover, HardcoverId, Image, ImageSource, LookUpContentError,
    SearchResult,
};
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{body_partial_json, body_string_contains, header, method, path},
};

use crate::support::{
    self, FakeHardcover,
    fake_hardcover::{TOKEN, fixture},
};

/// Returns Hardcover's answer to a search that found `found` Books, with these on its page.
fn search_page(found: u32, documents: &[Value]) -> Value {
    let hits: Vec<_> = documents
        .iter()
        .map(|document| json!({"document": document}))
        .collect();
    json!({"data": {"search": {"results": {"found": found, "page": 1, "hits": hits}}}})
}

/// Returns a Book in Hardcover's search results with this ID and title, and nothing else.
fn book(id: u32, title: &str) -> Value {
    json!({
        "id": id.to_string(),
        "title": title,
        "release_year": null,
        "release_date": null,
        "description": null,
        "image": {"url": null, "width": null, "height": null, "color": null},
        "contributions": [],
    })
}

#[tokio::test]
async fn search_returns_the_best_matches_and_most_read_books_first_with_their_creators() {
    let hardcover = FakeHardcover::start().await;
    Mock::given(method("POST"))
        .and(path("/graphql"))
        .and(header("authorization", format!("Bearer {TOKEN}")))
        .and(body_partial_json(json!({
            "variables": {"query": "asterix", "page": 1, "perPage": 20},
        })))
        .and(body_string_contains(
            "_text_match(buckets: 3):desc,users_count:desc",
        ))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_books")))
        .expect(1)
        .mount(&hardcover.server)
        .await;

    let found = hardcover
        .client()
        .search("asterix", NonZeroU32::MIN)
        .await
        .unwrap();

    assert_eq!(found.results.len(), 20);
    assert_eq!(
        found.results[1],
        SearchResult {
            external_content_id: ExternalContentId::Book(HardcoverId::new(474_594)),
            title: "Asterix and the Golden Sickle".to_owned(),
            date: Some(date(1961, 1, 1)),
            overview: Some(
                "Getafix has broken his golden sickle, so Asterix and Obelix visit Lutetia to buy \
                 a new one for him. But the sicklesmith—a cousin of Obelix—has vanished without a \
                 trace. Where could he have gone? And can Asterix solve the mystery and bring \
                 Getafix what he needs?"
                    .to_owned()
            ),
            poster: Image::new([ImageSource {
                url: "https://assets.hardcover.app/edition/30395784/\
                      ceee7f04890930494ba86a1e0f009c2ca83ee5dd.jpeg"
                    .to_owned(),
                width: 376,
                height: 500,
            }]),
            // Without the translators
            creators: vec!["René Goscinny".to_owned(), "Albert Uderzo".to_owned()],
        }
    );
    // The fixture is the first page of 194 Books
    assert_eq!(found.next_page, NonZeroU32::new(2));
}

#[tokio::test]
async fn search_signs_in_with_the_token_as_hardcover_shows_it() {
    let hardcover = FakeHardcover::start().await;
    Mock::given(method("POST"))
        .and(header("authorization", format!("Bearer {TOKEN}")))
        .respond_with(ResponseTemplate::new(200).set_body_json(search_page(0, &[])))
        .expect(1)
        .mount(&hardcover.server)
        .await;
    let token = SecretString::from(format!("Bearer {TOKEN}"));
    let client = Hardcover::with_base_url(
        &support::http_client(),
        &token,
        hardcover.server.uri().parse().unwrap(),
    )
    .unwrap();

    client.search("asterix", NonZeroU32::MIN).await.unwrap();
}

#[tokio::test]
async fn search_leaves_out_what_hardcover_lacks() {
    let hardcover = FakeHardcover::start().await;
    let mut untitled = book(1, "Untitled");
    untitled["description"] = json!(" \r\n");
    hardcover
        .answer("SearchBooks", search_page(1, &[untitled]))
        .await;

    let found = hardcover
        .client()
        .search("untitled", NonZeroU32::MIN)
        .await
        .unwrap();

    let result = &found.results[0];
    assert_eq!(result.date, None);
    assert_eq!(result.overview, None);
    assert_eq!(result.poster, None);
    assert_eq!(result.creators, [] as [String; 0]);
}

#[tokio::test]
async fn search_lists_a_creator_once_and_counts_a_contribution_without_a_role() {
    let hardcover = FakeHardcover::start().await;
    let mut asterix = book(1, "Asterix");
    asterix["contributions"] = json!([
        {"author": {"name": "René Goscinny"}, "contribution": null},
        {"author": {"name": "Albert Uderzo"}, "contribution": "Author"},
        {"author": {"name": "Albert Uderzo"}, "contribution": "Illustrations"},
        {"author": {"name": "Anthea Bell"}, "contribution": "Translator"},
    ]);
    hardcover
        .answer("SearchBooks", search_page(1, &[asterix]))
        .await;

    let found = hardcover
        .client()
        .search("asterix", NonZeroU32::MIN)
        .await
        .unwrap();

    assert_eq!(
        found.results[0].creators,
        ["René Goscinny", "Albert Uderzo"]
    );
}

#[tokio::test]
async fn search_has_no_next_page_once_every_book_is_on_a_page() {
    let hardcover = FakeHardcover::start().await;
    hardcover
        .answer("SearchBooks", search_page(40, &[book(1, "Dune")]))
        .await;
    let client = hardcover.client();

    let second = client.search("dune", NonZeroU32::new(2).unwrap()).await;
    let first = client.search("dune", NonZeroU32::MIN).await;

    assert_eq!(second.unwrap().next_page, None);
    assert_eq!(first.unwrap().next_page, NonZeroU32::new(2));
}

#[tokio::test]
async fn search_fails_with_the_errors_hardcover_answers() {
    let hardcover = FakeHardcover::start().await;
    hardcover
        .answer(
            "SearchBooks",
            json!({"errors": [{
                "message": "field 'nope' not found in type: 'books'",
                "extensions": {"code": "validation-failed"},
            }]}),
        )
        .await;

    let error = hardcover
        .client()
        .search("dune", NonZeroU32::MIN)
        .await
        .unwrap_err();

    assert_eq!(
        format!("{error:#}"),
        "Hardcover failed a query: field 'nope' not found in type: 'books'"
    );
}

#[tokio::test]
async fn search_fails_with_the_status_hardcover_answers() {
    let hardcover = FakeHardcover::start().await;
    Mock::given(method("POST"))
        .respond_with(ResponseTemplate::new(401).set_body_json(json!({
            "error": "invalid_token",
            "error_description": "Token is not associated with a user",
        })))
        .mount(&hardcover.server)
        .await;

    let error = hardcover
        .client()
        .search("dune", NonZeroU32::MIN)
        .await
        .unwrap_err();

    let error = format!("{error:#}");
    assert!(
        error.starts_with("HTTP status client error (401 Unauthorized) for url"),
        "{error}"
    );
}

#[tokio::test]
async fn fetch_book_returns_it_with_its_authors_and_no_media() {
    let hardcover = FakeHardcover::start().await;
    Mock::given(method("POST"))
        .and(path("/graphql"))
        .and(body_partial_json(json!({"variables": {"id": 442_623}})))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("book")))
        .expect(1)
        .mount(&hardcover.server)
        .await;

    let book = hardcover
        .client()
        .fetch_book(HardcoverId::new(442_623))
        .await
        .unwrap();

    assert_eq!(book.id, ExternalContentId::Book(HardcoverId::new(442_623)));
    assert_eq!(book.original_title, "Asterix the Gaul");
    assert_eq!(book.release_date, Some(date(1961, 9, 1)));
    assert!(book.texts.overviews.original.is_some());
    assert_eq!(
        book.texts.posters.original.unwrap().sources(),
        [ImageSource {
            url: "https://assets.hardcover.app/edition/17733379/1b12f2204159c59a4c5f644014bc1ada55440d4e.jpeg".to_owned(),
            width: 377,
            height: 500,
        }]
    );
    let credits: Vec<_> = book
        .credits
        .iter()
        .map(|credit| (credit.kind, credit.name.as_str(), credit.photo.is_some()))
        .collect();
    assert_eq!(
        credits,
        [
            (CreditKind::Author, "René Goscinny", true),
            (CreditKind::Author, "Albert Uderzo", false),
        ]
    );
    assert_eq!(book.media, []);
}

#[tokio::test]
async fn fetch_book_credits_each_person_once_per_role_and_leaves_out_translators() {
    let hardcover = FakeHardcover::start().await;
    let contribution = |id: u32, name: &str, role: Option<&str>| json!({"contribution": role, "author": {"id": id, "name": name, "image": null}});
    hardcover
        .answer(
            "Book",
            json!({"data": {"books_by_pk": {
                "title": "Asterix the Gaul",
                "contributions": [
                    contribution(1, "René Goscinny", None),
                    contribution(1, "René Goscinny", Some("Author")),
                    contribution(2, "Albert Uderzo", Some("Illustrations")),
                    contribution(3, "Anthea Bell", Some("Translator")),
                ],
            }}}),
        )
        .await;

    let book = hardcover
        .client()
        .fetch_book(HardcoverId::new(442_623))
        .await
        .unwrap();

    let credits: Vec<_> = book
        .credits
        .iter()
        .map(|credit| (credit.kind, credit.name.as_str()))
        .collect();
    assert_eq!(
        credits,
        [
            (CreditKind::Author, "René Goscinny"),
            (CreditKind::Illustrator, "Albert Uderzo"),
        ]
    );
}

#[tokio::test]
async fn look_up_book_fails_with_not_found_when_hardcover_has_no_book_with_the_id() {
    let hardcover = FakeHardcover::start().await;
    hardcover
        .answer("Book", json!({"data": {"books_by_pk": null}}))
        .await;

    let error = hardcover
        .client()
        .fetch_book(HardcoverId::new(999_999_999))
        .await
        .unwrap_err();

    assert!(matches!(error, LookUpContentError::NotFound), "{error:?}");
}

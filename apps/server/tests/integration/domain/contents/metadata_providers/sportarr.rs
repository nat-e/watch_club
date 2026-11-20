use std::num::NonZeroU32;

use jiff::civil::date;
use serde_json::{Value, json};
use watch_club::domain::contents::{
    CreditKind, ExternalContentId, Image, ImageSource, LookUpContentError, MediaType, SearchResult,
    SportarrId,
};
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{method, path},
};

use crate::support::{FakeSportarr, fake_sportarr::fixture};

/// Returns sportarr.net's answer to a search that found these Sports Events.
fn search_answer(events: &[Value]) -> Value {
    json!({"data": {"search": events}})
}

#[tokio::test]
async fn search_returns_the_events_with_the_querys_words_in_their_title_without_their_description()
{
    let sportarr = FakeSportarr::start().await;
    Mock::given(method("GET"))
        // `%` stands for any text, in place of the spaces and punctuation
        .and(path("/search/event/Canelo%25%C3%81lvarez%25vs%25Berlanga"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_events")))
        .expect(1)
        .mount(&sportarr.server)
        .await;

    let found = sportarr
        .client()
        .search("Canelo Álvarez vs. Berlanga", NonZeroU32::MIN)
        .await
        .unwrap();

    // The fixture is sportarr.net's answer to `canelo`
    assert_eq!(found.results.len(), 18);
    assert_eq!(
        found.results[3],
        SearchResult {
            external_content_id: ExternalContentId::SportsEvent(SportarrId::new("ev-575969")),
            title: "Canelo Álvarez vs Edgar Berlanga".to_owned(),
            date: Some(date(2024, 9, 15)),
            overview: None,
            poster: Image::new([ImageSource {
                url: "https://sportarr.net/static/images/event/58/\
                      58ab0873-e360-4e8f-b6ea-eed1f9378de4/poster_thesportsdb_b6a5111271d5.jpg\
                      ?v=g1-b6a5111271d5"
                    .to_owned(),
                width: 680,
                height: 1000,
            }]),
            creators: vec!["Boxing".to_owned()],
        }
    );
    assert_eq!(found.next_page, None);
}

#[tokio::test]
async fn search_calls_sportarr_anonymously() {
    let sportarr = FakeSportarr::start().await;
    sportarr
        .answer("/search/event/canelo", search_answer(&[]))
        .await;

    sportarr
        .client()
        .search("canelo", NonZeroU32::MIN)
        .await
        .unwrap();

    let requests = sportarr.server.received_requests().await.unwrap();
    assert!(!requests[0].headers.contains_key("authorization"));
}

#[tokio::test]
async fn search_leaves_out_what_sportarr_lacks() {
    let sportarr = FakeSportarr::start().await;
    let event = json!({
        "idEvent": "ev-1",
        "strEvent": "Untitled",
        "strLeague": "",
        "dateEvent": null,
        "strPoster": null,
    });
    sportarr
        .answer("/search/event/untitled", search_answer(&[event]))
        .await;

    let found = sportarr
        .client()
        .search("untitled", NonZeroU32::MIN)
        .await
        .unwrap();

    let result = &found.results[0];
    assert_eq!(
        (result.date, &result.poster, result.creators.as_slice()),
        (None, &None, [].as_slice())
    );
}

#[tokio::test]
async fn search_finds_nothing_on_the_next_pages_without_asking_sportarr() {
    let sportarr = FakeSportarr::start().await;

    let found = sportarr
        .client()
        .search("canelo", NonZeroU32::new(2).unwrap())
        .await
        .unwrap();

    assert_eq!(found.results, []);
    assert!(
        sportarr
            .server
            .received_requests()
            .await
            .unwrap()
            .is_empty()
    );
}

#[tokio::test]
async fn search_fails_with_the_status_sportarr_answers() {
    let sportarr = FakeSportarr::start().await;
    Mock::given(method("GET"))
        .respond_with(ResponseTemplate::new(400).set_body_string("Bad Request"))
        .mount(&sportarr.server)
        .await;

    let error = sportarr
        .client()
        .search("canelo", NonZeroU32::MIN)
        .await
        .unwrap_err();

    let error = format!("{error:#}");
    assert!(
        error.starts_with(
            "failed to search sportarr.net: HTTP status client error (400 Bad Request) for url"
        ),
        "{error}"
    );
}

#[tokio::test]
async fn fetch_sports_event_returns_it_with_its_one_media() {
    let sportarr = FakeSportarr::start().await;
    sportarr
        .answer("/lookup/event/ev-575969", fixture("event"))
        .await;

    let event = sportarr
        .client()
        .fetch_sports_event(&SportarrId::new("ev-575969"))
        .await
        .unwrap();

    assert_eq!(
        event.id,
        ExternalContentId::SportsEvent(SportarrId::new("ev-575969"))
    );
    assert_eq!(event.original_title, "Canelo Álvarez vs Edgar Berlanga");
    assert_eq!(event.release_date, Some(date(2024, 9, 15)));
    assert_eq!(event.origin_country.as_deref(), Some("US"));
    assert!(event.texts.overviews.original.is_some());
    assert!(event.texts.posters.original.is_some());
    assert_eq!(
        event.backdrop.unwrap().sources(),
        [ImageSource {
            url: "https://sportarr.net/static/images/event/58/58ab0873-e360-4e8f-b6ea-eed1f9378de4/backdrop_thesportsdb_3e52cef8a113.jpg?v=g1-3e52cef8a113".to_owned(),
            width: 1280,
            height: 720,
        }]
    );
    let credits: Vec<_> = event
        .credits
        .iter()
        .map(|credit| (credit.kind, credit.name.as_str()))
        .collect();
    assert_eq!(credits, [(CreditKind::League, "Boxing")]);
    assert_eq!(event.media.len(), 1);
    assert_eq!(event.media[0].media_type, MediaType::SportsEvent);
    assert_eq!(event.media[0].release_date, Some(date(2024, 9, 15)));
}

#[tokio::test]
async fn look_up_fails_with_not_found_when_sportarr_doesnt_know_the_id() {
    let sportarr = FakeSportarr::start().await;
    sportarr
        .answer("/lookup/event/ev-0", json!({"data": []}))
        .await;

    let error = sportarr
        .client()
        .fetch_sports_event(&SportarrId::new("ev-0"))
        .await
        .unwrap_err();

    assert!(matches!(error, LookUpContentError::NotFound), "{error:?}");
}

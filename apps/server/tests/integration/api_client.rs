//! The addresses of the APIs WatchClub calls, through `api_client::ApiUrl`.

use watch_club::api_client::ApiUrl;

#[test]
fn parses_a_url_that_can_have_a_path() {
    let url: ApiUrl = " http://radarr:7878 ".parse().unwrap();

    assert_eq!(url.as_str(), "http://radarr:7878/");
}

#[test]
fn refuses_text_that_isnt_a_url_that_can_have_a_path() {
    // `radarr:7878` is a URL whose scheme is `radarr`
    for text in ["", "radarr", "radarr:7878", "http://"] {
        assert!(text.parse::<ApiUrl>().is_err(), "{text:?}");
    }
}

#[test]
fn adds_segments_after_the_urls_path() {
    // Such as behind a reverse proxy
    for text in ["http://media.local/radarr", "http://media.local/radarr/"] {
        let url: ApiUrl = text.parse().unwrap();

        let joined = url.join(["api", "v3"]);

        assert_eq!(
            joined.as_str(),
            "http://media.local/radarr/api/v3",
            "{text}"
        );
    }
}

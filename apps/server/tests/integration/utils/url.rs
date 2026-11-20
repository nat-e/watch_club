//! The URLs that someone enters, through `utils::url`.

use watch_club::utils::url::tidy_http_url;

#[test]
fn returns_the_url_without_the_spaces_around_it_or_a_trailing_slash() {
    for (text, url) in [
        ("http://radarr:7878", "http://radarr:7878"),
        (
            " https://radarr.example.com/ ",
            "https://radarr.example.com",
        ),
        // Such as behind a reverse proxy
        ("http://media.local/radarr/", "http://media.local/radarr"),
    ] {
        assert_eq!(tidy_http_url(text).as_deref(), Some(url), "{text:?}");
    }
}

#[test]
fn refuses_text_that_isnt_an_http_or_https_url() {
    // `radarr:7878` is a URL whose scheme is `radarr`
    for text in ["", "radarr", "radarr:7878", "ftp://radarr", "http://"] {
        assert_eq!(tidy_http_url(text), None, "{text:?}");
    }
}

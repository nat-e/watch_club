//! Localizations: the texts of a Content and of its Media in each Locale.
//!
//! Metadata Providers have texts in the languages people translated them into. Saving picks one
//! for each Locale, so that every Content and Media has a localization in every Locale, and reads
//! take the User's Locale as is.

use super::Image;
use crate::domain::accounts::Locale;

/// A language a Metadata Provider has a text in: an ISO 639-1 code, such as `fr`, with the ISO
/// 3166-1 code of the country it's written for, such as `CA`, when it says one.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Language {
    pub code: String,
    pub country: Option<String>,
}

impl Language {
    pub fn new(code: impl Into<String>, country: Option<String>) -> Self {
        Self {
            code: code.into(),
            country,
        }
    }

    /// Whether a text in this language suits the Locale: it's in the Locale's language, for the
    /// Locale's country or for none in particular.
    fn suits(&self, locale: Locale) -> bool {
        self.code == locale.language()
            && self
                .country
                .as_deref()
                .is_none_or(|country| country == locale.country())
    }

    fn is_english(&self) -> bool {
        self.code == "en"
    }
}

impl From<Locale> for Language {
    fn from(locale: Locale) -> Self {
        Self::new(locale.language(), Some(locale.country().to_owned()))
    }
}

/// A value a Metadata Provider has in several languages, such as a title or a poster.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Translations<T> {
    /// The value in the Content's original language, or the one its Metadata Provider gives when
    /// it doesn't say the language
    pub original: Option<T>,
    /// The value in each language it's translated into. When a language has several, the first is
    /// the best
    pub translated: Vec<(Language, T)>,
}

impl<T> Default for Translations<T> {
    fn default() -> Self {
        Self {
            original: None,
            translated: Vec::new(),
        }
    }
}

impl<T> Translations<T> {
    /// Returns a value its Metadata Provider has only as it is, untranslated.
    pub fn original(value: Option<T>) -> Self {
        Self {
            original: value,
            translated: Vec::new(),
        }
    }

    /// Returns the value for the Locale: the Locale's, else English's, else the original's.
    fn pick(&self, locale: Locale) -> Option<&T> {
        self.find_translated(|language| language.suits(locale))
            .or_else(|| self.find_translated(Language::is_english))
            .or(self.original.as_ref())
    }

    /// Returns the best value in a language that `is_wanted` accepts.
    fn find_translated(&self, is_wanted: impl Fn(&Language) -> bool) -> Option<&T> {
        self.translated
            .iter()
            .find(|(language, _)| is_wanted(language))
            .map(|(_, value)| value)
    }
}

/// A Content's texts and poster in every language its Metadata Provider has them.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ContentTranslations {
    pub titles: Translations<String>,
    pub overviews: Translations<String>,
    pub posters: Translations<Image>,
    /// The YouTube URLs of its trailers
    pub trailer_urls: Translations<String>,
}

/// A Content's texts and poster in one Locale, as saving writes them.
#[derive(Debug)]
pub(super) struct ContentLocalization<'a> {
    pub locale: Locale,
    pub title: &'a str,
    pub overview: Option<&'a str>,
    pub poster: Option<&'a Image>,
    pub trailer_url: Option<&'a str>,
}

impl ContentTranslations {
    /// Returns the Content's localization in each Locale. Each text is the Locale's, else
    /// English's, else the original's, and a Content without any title has its original title.
    pub(super) fn localize<'a>(
        &'a self,
        original_title: &'a str,
    ) -> impl Iterator<Item = ContentLocalization<'a>> {
        Locale::ALL
            .into_iter()
            .map(move |locale| ContentLocalization {
                locale,
                title: self
                    .titles
                    .pick(locale)
                    .map_or(original_title, String::as_str),
                overview: self.overviews.pick(locale).map(String::as_str),
                poster: self.posters.pick(locale),
                trailer_url: self.trailer_urls.pick(locale).map(String::as_str),
            })
    }
}

/// A Media's texts in every language its Metadata Provider has them.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MediaTranslations {
    pub titles: Translations<String>,
    pub overviews: Translations<String>,
}

/// A Media's texts in one Locale, as saving writes them.
#[derive(Debug)]
pub(super) struct MediaLocalization<'a> {
    pub locale: Locale,
    pub title: Option<&'a str>,
    pub overview: Option<&'a str>,
}

impl MediaTranslations {
    /// Returns the Media's localization in each Locale. Each text is the Locale's, else English's,
    /// else the original's.
    pub(super) fn localize(&self) -> impl Iterator<Item = MediaLocalization<'_>> {
        Locale::ALL.into_iter().map(|locale| MediaLocalization {
            locale,
            title: self.titles.pick(locale).map(String::as_str),
            overview: self.overviews.pick(locale).map(String::as_str),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn translations(
        original: Option<&str>,
        translated: &[(&str, Option<&str>, &str)],
    ) -> Translations<String> {
        Translations {
            original: original.map(str::to_owned),
            translated: translated
                .iter()
                .map(|(code, country, value)| {
                    (
                        Language::new(*code, country.map(str::to_owned)),
                        (*value).to_owned(),
                    )
                })
                .collect(),
        }
    }

    #[test]
    fn picks_the_locales_text() {
        let titles = translations(
            Some("Le Fabuleux Destin d'Amélie Poulain"),
            &[
                ("en", Some("US"), "Amélie"),
                ("fr", Some("FR"), "Amélie Poulain"),
            ],
        );

        assert_eq!(titles.pick(Locale::FrFr).unwrap(), "Amélie Poulain");
        assert_eq!(titles.pick(Locale::EnUs).unwrap(), "Amélie");
    }

    #[test]
    fn takes_a_text_without_a_country_for_any_country_of_its_language() {
        let titles = translations(
            None,
            &[("en", Some("US"), "The Matrix"), ("fr", None, "Matrix")],
        );

        assert_eq!(titles.pick(Locale::FrFr).unwrap(), "Matrix");
    }

    #[test]
    fn falls_back_on_english_rather_than_another_country() {
        let titles = translations(
            Some("Breaking Bad"),
            &[
                ("fr", Some("CA"), "Breaking Bad : Le chimiste"),
                ("en", Some("GB"), "Breaking Bad (UK)"),
            ],
        );

        assert_eq!(titles.pick(Locale::FrFr).unwrap(), "Breaking Bad (UK)");
    }

    #[test]
    fn falls_back_on_the_original_without_english() {
        let titles = translations(
            Some("千と千尋の神隠し"),
            &[("de", Some("DE"), "Chihiros Reise")],
        );

        assert_eq!(titles.pick(Locale::FrFr).unwrap(), "千と千尋の神隠し");
    }

    #[test]
    fn localizes_every_locale_with_the_original_title_when_nothing_has_one() {
        let texts = ContentTranslations {
            overviews: translations(None, &[("en", Some("US"), "A hacker learns the truth.")]),
            ..ContentTranslations::default()
        };

        let localizations: Vec<_> = texts.localize("The Matrix").collect();

        assert_eq!(localizations.len(), Locale::ALL.len());
        for localization in localizations {
            assert_eq!(localization.title, "The Matrix");
            assert_eq!(localization.overview, Some("A hacker learns the truth."));
        }
    }
}

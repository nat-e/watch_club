//! Images: the pictures of a Content, such as its poster, in the sizes its Metadata Provider has.

use serde::Serialize;
use utoipa::ToSchema;

/// A picture in each size its Metadata Provider has, from the narrowest, so that the apps can
/// download the smallest one that stays sharp.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
#[schema(min_items = 1)]
pub struct Image(Vec<ImageSource>);

/// One size of an Image.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct ImageSource {
    pub url: String,
    /// Its width, in pixels
    pub width: u32,
    /// Its height, in pixels
    pub height: u32,
}

impl Image {
    /// Returns the image in these sizes, from the narrowest, keeping one per width, or None
    /// without any.
    pub fn new(sources: impl IntoIterator<Item = ImageSource>) -> Option<Self> {
        let mut sources: Vec<_> = sources.into_iter().collect();
        sources.sort_by_key(|source| source.width);
        sources.dedup_by_key(|source| source.width);
        (!sources.is_empty()).then_some(Self(sources))
    }
}

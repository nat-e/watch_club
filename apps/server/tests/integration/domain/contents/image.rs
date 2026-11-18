use serde_json::json;
use watch_club::domain::contents::{Image, ImageSource};

/// Returns a 2:3 size of an image, this wide, at an address with this name.
fn source(width: u32, name: &str) -> ImageSource {
    ImageSource {
        url: format!("https://images.example.com/{name}.jpg"),
        width,
        height: width * 3 / 2,
    }
}

#[test]
fn new_sorts_the_sizes_from_the_narrowest_and_keeps_the_first_of_each_width() {
    let image = Image::new([
        source(342, "large"),
        source(92, "small"),
        source(342, "other"),
    ]);

    assert_eq!(
        serde_json::to_value(image).unwrap(),
        json!([
            {"url": "https://images.example.com/small.jpg", "width": 92, "height": 138},
            {"url": "https://images.example.com/large.jpg", "width": 342, "height": 513},
        ])
    );
}

#[test]
fn new_returns_none_without_sizes() {
    assert_eq!(Image::new([]), None);
}

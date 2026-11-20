//! Conversions between units of time.

/// Returns a duration in minutes in seconds, or `i32::MAX` for one too long to fit.
pub(crate) fn minutes_to_seconds(minutes: i32) -> i32 {
    minutes.saturating_mul(60)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn minutes_to_seconds_multiplies_by_60_up_to_the_largest_i32() {
        assert_eq!(minutes_to_seconds(122), 7_320);
        assert_eq!(minutes_to_seconds(i32::MAX), i32::MAX);
    }
}

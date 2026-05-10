defmodule WatchClubWeb.Helpers.Time do
  @spec relative_from_now(DateTime.t()) :: String.t()
  def relative_from_now(date) do
    diff = DateTime.diff(DateTime.utc_now(), date)

    cond do
      diff < 60 -> "just now"
      diff < 120 -> "1 minute ago"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 7200 -> "1 hour ago"
      diff < 86_400 -> "#{div(diff, 3600)} hours ago"
      diff < 172_800 -> "1 day ago"
      diff < 604_800 -> "#{div(diff, 86_400)} days ago"
      diff < 1_209_600 -> "1 week ago"
      diff < 2_419_200 -> "#{div(diff, 604_800)} weeks ago"
      true -> Calendar.strftime(date, "%b %d, %Y")
    end
  end
end

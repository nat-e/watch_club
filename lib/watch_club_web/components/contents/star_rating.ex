defmodule WatchClubWeb.Components.Contents.StarRating do
  @moduledoc """
  A Movie's or TV Show's Rating: a gold star and the number, to one decimal in the User's
  locale, such as "★ 7,3" in French.
  """
  use WatchClubWeb, :component

  attr :rating, :float, required: true, doc: "out of 10, from `WatchClub.Contents.Rating`"
  attr :locale, :atom, required: true, doc: "a `UserLocale`"
  attr :class, :any, default: nil

  def star_rating(assigns) do
    ~H"""
    <span class={["inline-flex items-center gap-tight font-semibold", @class]}>
      <Lucideicons.star class="size-icon-sm fill-current text-warning" />
      {WatchClub.Cldr.Number.to_string!(@rating,
        fractional_digits: 1,
        locale: UserLocale.to_cldr_locale_name(@locale)
      )}
    </span>
    """
  end
end

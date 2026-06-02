defmodule WatchClubWeb.Components.Contents.Details.ReviewsCard do
  @moduledoc """
  TMDB reviews score card shared by the Movie and TV Show detail pages.
  """
  use WatchClubWeb, :component

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Contents.ContentView

  attr :content, ContentView, required: true
  attr :current_user, User, required: true

  def reviews_card(assigns) do
    ~H"""
    <.section
      :if={format_score(@content.details.vote_average)}
      title={dgettext("contents", "Reviews")}
      icon={:star}
    >
      <div class="grid place-items-center gap-related text-center">
        <div
          class="grid size-24 place-items-center rounded-full p-1"
          style={"background: conic-gradient(var(--wc-color-success) #{score_percent(@content.details.vote_average)}%, var(--wc-color-surface-inset) 0)"}
        >
          <div class="grid size-full place-items-center rounded-full bg-surface-overlay">
            <div>
              <p class="text-2xl font-semibold text-text">
                {format_score(@content.details.vote_average)}
              </p>
              <p class="text-xs text-text-muted">TMDB</p>
            </div>
          </div>
        </div>
        <p :if={@content.details.vote_count} class="text-sm leading-6 text-text-muted">
          {dngettext(
            "contents",
            "Based on %{count} TMDB vote.",
            "Based on %{count} TMDB votes.",
            @content.details.vote_count,
            count: format_vote_count(@content.details.vote_count, @current_user.settings.locale)
          )}
        </p>
      </div>
    </.section>
    """
  end

  defp format_score(score) when is_number(score) do
    score
    |> Kernel.*(1.0)
    |> :erlang.float_to_binary(decimals: 1)
  end

  defp format_score(_), do: nil

  defp score_percent(score) when is_number(score) do
    score
    |> Kernel.*(10)
    |> round()
    |> max(0)
    |> min(100)
  end

  defp score_percent(_), do: 0

  defp format_vote_count(count, locale) do
    WatchClub.Cldr.Number.to_string!(count, locale: UserLocale.to_cldr_locale_name(locale))
  end
end

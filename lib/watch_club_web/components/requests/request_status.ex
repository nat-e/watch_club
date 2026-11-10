defmodule WatchClubWeb.Components.Requests.RequestStatus do
  @moduledoc """
  When a requested Content can be watched: an icon for its Content Request Status, a few words,
  and a bar while it downloads, as My Requests shows it. `status_icon/1` and `status_words/3`
  let `PlayOrRequestButton` say it in one line.
  """
  use WatchClubWeb, :component

  attr :request, ContentRequest,
    required: true,
    doc:
      "with its `status`, `download_progress`, `aired_episodes_count` and `aired_episodes_with_media_count`"

  attr :release_date, Date, default: nil, doc: "the Content's, for when it's not released yet"
  attr :locale, :atom, required: true, doc: "a `UserLocale`"
  attr :rest, :global

  def request_status(assigns) do
    ~H"""
    <span class="flex min-w-0 flex-col" {@rest}>
      <span class="flex gap-tight text-sm text-text-muted">
        <span class="flex h-lh shrink-0 items-center">
          <.status_icon status={@request.status} />
        </span>
        {when_watchable(@request, @release_date, @locale)}
      </span>
      <.progress_bar
        :if={@request.status == :downloading}
        percent={@request.download_progress}
        class="mt-related max-w-48"
      />
    </span>
    """
  end

  attr :status, :atom, required: true, doc: "a `ContentRequestStatus`"

  attr :class, :any,
    default: "size-icon-sm",
    doc: "its size, and a color with a trailing `!` to replace its own"

  @doc "An icon for a Content Request Status, in its color."
  def status_icon(assigns) do
    ~H"""
    <Lucideicons.download
      :if={@status in [:importing, :downloading]}
      class={["shrink-0 text-accent", @class]}
      aria-hidden="true"
    />
    <Lucideicons.search
      :if={@status == :searching}
      class={["shrink-0 text-text-subtle", @class]}
      aria-hidden="true"
    />
    <Lucideicons.calendar
      :if={@status == :not_released}
      class={["shrink-0 text-text-subtle", @class]}
      aria-hidden="true"
    />
    <Lucideicons.search_x
      :if={@status == :not_found}
      class={["shrink-0 text-text-subtle", @class]}
      aria-hidden="true"
    />
    <Lucideicons.circle_alert
      :if={@status == :failed}
      class={["shrink-0 text-danger", @class]}
      aria-hidden="true"
    />
    """
  end

  # My Requests says a little more when it's stuck
  defp when_watchable(%ContentRequest{status: :not_found}, _release_date, _locale),
    do: dgettext("requests", "Not found, we'll keep looking for it")

  defp when_watchable(%ContentRequest{status: :failed}, _release_date, _locale),
    do: dgettext("requests", "There was a problem, the instance administrator was told")

  # Once some of its TV Show Episodes have Media, how many. Nil for a Movie.
  defp when_watchable(
         %ContentRequest{
           status: status,
           aired_episodes_with_media_count: ready,
           aired_episodes_count: aired
         },
         _release_date,
         _locale
       )
       when status in [:downloading, :importing] and is_integer(ready) and ready > 0,
       do:
         dngettext(
           "requests",
           "%{ready} of %{count} episode ready",
           "%{ready} of %{count} episodes ready",
           aired,
           ready: ready
         )

  defp when_watchable(request, release_date, locale),
    do: status_words(request, release_date, locale)

  @doc """
  When a requested Content can be watched, in words that fit on one line. The release date is
  the Content's, for when it's not released yet.
  """
  # Completed, its Content can only be out of the Library once its Media was deleted
  def status_words(%ContentRequest{status: status}, _release_date, _locale)
      when status in [:importing, :searching, :completed],
      do: ContentRequestStatus.translated_label(status)

  def status_words(%ContentRequest{status: :downloading} = request, _release_date, _locale),
    do: dgettext("requests", "%{percent}% downloaded", percent: round(request.download_progress))

  # TMDB's date is often the cinema release, before the one we can download
  def status_words(%ContentRequest{status: :not_released}, release_date, locale) do
    if release_date && Date.after?(release_date, Date.utc_today()),
      do: dgettext("requests", "Out on %{date}", date: Time.long_date(release_date, locale)),
      else: dgettext("requests", "Not released yet")
  end

  def status_words(%ContentRequest{status: :not_found}, _release_date, _locale),
    do: dgettext("requests", "Not found, still looking")

  def status_words(%ContentRequest{status: :failed}, _release_date, _locale),
    do: dgettext("requests", "Error downloading")
end

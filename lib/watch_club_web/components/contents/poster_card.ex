defmodule WatchClubWeb.Components.Contents.PosterCard do
  @moduledoc """
  A Content's poster that opens its page, as on Browse: the avatars of who recommended it to the
  User, a badge once watched or while in progress, and on hover its name, rating, original
  language and year, with its Play button. Screens that can't hover show them on a first tap, and
  the next one opens the Content or plays it.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.StarRating
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Languages

  attr :content, Content,
    required: true,
    doc: "with its `implementation`, `actor_progress_status` and `actor_recommendations` loaded"

  attr :locale, :atom, required: true, doc: "the User's locale"

  attr :ready_unseen, :boolean,
    default: false,
    doc: "ringed, with a New badge instead of its progress"

  slot :action, required: true, doc: "its Play button, which shows on hover"

  def poster_card(assigns) do
    assigns =
      assigns
      |> assign(:title, assigns.content.implementation.best_localization.title)
      |> assign(:badge_id, "poster-badge-#{assigns.content.id}")
      |> assign(:recommenders_id, "recommenders-#{assigns.content.id}")
      |> assign(
        :recommenders,
        assigns.content.actor_recommendations |> Enum.map(& &1.recommended_by) |> Enum.uniq()
      )

    ~H"""
    <div class="group relative">
      <.tmdb_poster
        path={@content.implementation.best_localization.poster_path}
        size="w342"
        class={[
          "w-full shadow-card",
          @ready_unseen && "ring-2 ring-accent ring-offset-2 ring-offset-canvas"
        ]}
      >
        <.recommenders id={@recommenders_id} users={@recommenders} locale={@locale} />
        <%!-- The link reads its badges --%>
        <.badge
          :if={@ready_unseen}
          id={@badge_id}
          aria-hidden="true"
          variant="accent"
          size="sm"
          class="absolute top-related right-related"
        >
          {dgettext("contents", "New")}
        </.badge>
        <.progress_badge
          :if={!@ready_unseen}
          id={@badge_id}
          status={@content.actor_progress_status}
        />
        <span
          aria-hidden="true"
          class="absolute inset-0 flex flex-col justify-end gap-related bg-linear-to-t from-black/90 via-black/60 to-transparent p-related opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100 group-data-revealed:opacity-100"
        >
          <span class="line-clamp-3 text-sm font-semibold text-white">{@title}</span>
          <span class="flex items-center gap-related text-xs text-white/80">
            <.star_rating
              :if={@content.rating}
              rating={@content.rating}
              locale={@locale}
              class="text-white"
            />
            <span
              :if={@content.original_language}
              class="text-base leading-none"
              title={
                dgettext("browse", "Original language: %{language}",
                  language: Languages.to_name(@content.original_language)
                )
              }
            >
              {Languages.to_flag(@content.original_language)}
            </span>
            <span :if={@content.release_date}>{@content.release_date.year}</span>
          </span>
        </span>
      </.tmdb_poster>
      <.link
        navigate={Url.content_details_link(ContentIdentity.from_content(@content))}
        aria-label={@title}
        aria-describedby={
          [
            @recommenders != [] && @recommenders_id,
            (@ready_unseen or @content.actor_progress_status in [:completed, :in_progress]) &&
              @badge_id
          ]
          |> Enum.filter(& &1)
          |> Enum.join(" ")
        }
        class="absolute inset-0 rounded-lg"
      ></.link>
      <div class="pointer-events-none absolute inset-0 grid place-items-center opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100 group-data-revealed:opacity-100">
        <div class="pointer-events-auto">{render_slot(@action)}</div>
      </div>
      <%!-- Screen readers reach the link and Play directly --%>
      <button
        type="button"
        aria-hidden="true"
        tabindex="-1"
        phx-click={reveal_poster()}
        class="absolute inset-0 rounded-lg [@media(hover:hover)]:hidden group-data-revealed:hidden"
      ></button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :users, :list, required: true, doc: "who recommended it to the User, the latest first"
  attr :locale, :atom, required: true

  # The avatars of who recommended it to the User
  defp recommenders(assigns) do
    assigns = assign(assigns, :label, recommended_by(assigns.users, assigns.locale))

    ~H"""
    <span
      :if={@users != []}
      id={@id}
      aria-hidden="true"
      role="img"
      aria-label={@label}
      title={@label}
      class="absolute top-related left-related"
    >
      <.avatar_group
        avatars={Enum.map(@users, &%{id: &1.id, name: &1.username})}
        avatar_size="sm"
        avatar_class="ring-2 ring-black/40"
        class="-space-x-1.5!"
      />
    </span>
    """
  end

  # "From guigui74", "From guigui74 and vinz", "From guigui74 and 2 others"
  defp recommended_by([user | others], _locale) when length(others) > 1 do
    dngettext(
      "browse",
      "From %{name} and %{count} other",
      "From %{name} and %{count} others",
      length(others),
      name: user.username
    )
  end

  defp recommended_by(users, locale) do
    names =
      users
      |> Enum.map(& &1.username)
      |> WatchClub.Cldr.List.to_string!(locale: UserLocale.to_cldr_locale_name(locale))

    dgettext("browse", "From %{names}", names: names)
  end

  attr :id, :string, required: true
  attr :status, :atom, required: true, doc: "a `WatchStatus`"

  # Watched or in progress
  defp progress_badge(assigns) do
    ~H"""
    <span
      :if={@status in [:completed, :in_progress]}
      id={@id}
      aria-hidden="true"
      role="img"
      aria-label={WatchStatus.translated_label(@status)}
      title={WatchStatus.translated_label(@status)}
      class="absolute top-related right-related grid size-7 place-items-center rounded-full bg-black/80"
    >
      <Lucideicons.check :if={@status == :completed} class="size-icon-sm text-success" />
      <Lucideicons.contrast :if={@status == :in_progress} class="size-icon-sm text-primary" />
    </span>
    """
  end

  # Shows a poster's name, rating and Play, as hover does, and hides the ones shown before
  defp reveal_poster do
    "data-revealed"
    |> JS.remove_attribute(to: "[data-revealed]")
    |> JS.set_attribute({"data-revealed", ""}, to: {:closest, ".group"})
  end
end

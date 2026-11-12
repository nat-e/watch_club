defmodule WatchClubWeb.HomePage.ActivityFeed do
  @moduledoc """
  The Activity Feed on Home: its Feed Entries, latest first, then Show more. Each entry is one
  sentence, such as "leadelpeut watched WAR, Severance S01E02, and Fleabag (3 episodes)".
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Accounts.UserAvatar
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.ActivityFeed.FeedEntry

  # Sentences and posters show this many Contents, then "and N more"
  @listed_count 3

  attr :stream, :list, required: true
  attr :more?, :boolean, required: true, doc: "whether Show more loads more entries"
  attr :locale, :atom, required: true

  # Hidden while it has neither entries nor more to show
  def activity_feed(assigns) do
    ~H"""
    <.page_section
      id="activity-feed-title"
      title={dgettext("home", "Activity")}
      class="not-has-[[data-activity]]:hidden"
    >
      <ol id="activity-feed" phx-update="stream" class="flex flex-col">
        <.feed_entry :for={{dom_id, entry} <- @stream} id={dom_id} entry={entry} locale={@locale} />
      </ol>
      <.button
        :if={@more?}
        id="activity-feed-more"
        data-activity
        variant="ghost"
        size="sm"
        phx-click="load_activity_feed_page"
        class="self-start"
      >
        {dgettext("home", "Show more")}
      </.button>
    </.page_section>
    """
  end

  attr :id, :string, required: true
  attr :entry, FeedEntry, required: true
  attr :locale, :atom, required: true

  # The time sits on the left of the line, or under the sentence in a narrow column. The posters
  # are hidden from screen readers, because the sentence already links each Content.
  defp feed_entry(assigns) do
    events = assigns.entry.events
    episodes = Enum.group_by(events, & &1.content_id, & &1.tv_show_episode)

    # Each Content once, latest first, with its TV Show Episodes
    {watched, more} =
      events
      |> Enum.map(& &1.content)
      |> Enum.uniq_by(& &1.id)
      |> Enum.map(&{&1, episodes[&1.id]})
      |> listed()

    assigns = assign(assigns, user: hd(events).actor, watched: watched, more: more)

    ~H"""
    <li id={@id} data-activity class="group/entry flex gap-related @xl:gap-group">
      <time
        datetime={DateTime.to_iso8601(@entry.latest_at)}
        class="hidden w-24 shrink-0 pt-0.5 text-right text-xs text-text-subtle @xl:block"
      >
        {Time.relative_from_now(@entry.latest_at, @locale)}
      </time>
      <div aria-hidden="true" class="flex w-2 shrink-0 flex-col items-center gap-tight pt-1.5">
        <span class="size-2 shrink-0 rounded-full bg-border"></span>
        <span class="w-px flex-1 bg-border-subtle group-last/entry:hidden"></span>
      </div>
      <.user_avatar user={@user} size="sm" aria-hidden="true" />
      <div class="flex min-w-0 flex-1 flex-col gap-related pb-cluster group-last/entry:pb-0">
        <div>
          <p class="text-sm text-text-muted">{sentence(@user, @watched, @more, @locale)}</p>
          <time
            datetime={DateTime.to_iso8601(@entry.latest_at)}
            class="block text-xs text-text-subtle @xl:hidden"
          >
            {Time.relative_from_now(@entry.latest_at, @locale)}
          </time>
        </div>
        <div aria-hidden="true" class="flex gap-related">
          <.link
            :for={{content, _episodes} <- @watched}
            navigate={Url.content_details_link(content)}
            tabindex="-1"
            class="block min-w-0 basis-12"
          >
            <.tmdb_poster
              size="w185"
              path={content.poster_path}
              class="w-full"
            />
          </.link>
          <span
            :if={@more > 0}
            class="flex aspect-2/3 min-w-0 basis-12 items-center justify-center rounded-lg bg-surface text-sm font-semibold text-text-muted"
          >
            +{@more}
          </span>
        </div>
      </div>
    </li>
    """
  end

  # "A", "A and B", "A, B, C, and 2 more", in the User's language. A TV Show reads as its TV Show
  # Episode, such as "Fleabag S01E03", or as how many, such as "Fleabag (3 episodes)".
  defp sentence(user, watched, more, locale) do
    contents =
      watched
      |> Enum.map(fn {content, episodes} -> watched_part(content, episodes) end)
      |> Enum.concat(
        if more > 0, do: [dngettext("home", "%{count} more", "%{count} more", more)], else: []
      )
      |> WatchClub.Cldr.List.to_string!(locale: UserLocale.to_cldr_locale_name(locale))

    dgettext("home", "%{user} watched %{contents}",
      user: gtspan(user.username, "font-semibold text-text"),
      contents: contents
    )
    |> raw()
  end

  # The items to show and how many are left. "and 1 more" or "+1" would take the place of the item
  # it hides, so one extra item is shown instead.
  defp listed(items) when length(items) <= @listed_count + 1, do: {items, 0}
  defp listed(items), do: {Enum.take(items, @listed_count), length(items) - @listed_count}

  # A Movie or Sports Event has no TV Show Episode
  defp watched_part(content, [nil]), do: sentence_part(content_link(%{content: content}))

  # The link only leads to the TV Show, so the episode stays outside it, kept on the same line
  defp watched_part(content, [episode]) do
    link = sentence_part(content_link(%{content: content}))
    "#{link}\u00A0#{episode.formatted_episode_number}"
  end

  defp watched_part(content, episodes) do
    dngettext(
      "home",
      "%{show} (%{count}\u00A0episode)",
      "%{show} (%{count}\u00A0episodes)",
      length(episodes),
      show: sentence_part(content_link(%{content: content}))
    )
  end

  # A component as HTML inside a translated sentence. The template's line breaks would show as a
  # space, such as before a comma.
  defp sentence_part(rendered), do: rendered |> gtcomponent() |> String.replace(~r/\s*\n\s*/, "")

  attr :content, Content, required: true

  defp content_link(assigns) do
    ~H"""
    <.link
      navigate={Url.content_details_link(@content)}
      class="font-semibold text-text hover:underline"
    >
      {@content.title}
    </.link>
    """
  end
end

defmodule WatchClubWeb.HomePage.ActivityFeed do
  @moduledoc """
  The Activity Feed on Home: its Feed Entries, latest first, then Show more. Each entry is one
  sentence, such as "leadelpeut is watching WAR, Dune, and Fleabag, and watched Privileges".
  """
  use WatchClubWeb, :component

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
    {posters, more_posters} = assigns.entry.events |> Enum.map(& &1.content) |> listed()

    assigns =
      assign(assigns,
        user: hd(assigns.entry.events).actor,
        posters: posters,
        more_posters: more_posters
      )

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
      <.avatar id={@user.id} name={@user.username} size="sm" aria-hidden="true" />
      <div class="flex min-w-0 flex-1 flex-col gap-related pb-cluster group-last/entry:pb-0">
        <div>
          <p class="text-sm text-text-muted">{sentence(@entry.events, @user, @locale)}</p>
          <time
            datetime={DateTime.to_iso8601(@entry.latest_at)}
            class="block text-xs text-text-subtle @xl:hidden"
          >
            {Time.relative_from_now(@entry.latest_at, @locale)}
          </time>
        </div>
        <div :if={@posters != []} aria-hidden="true" class="flex gap-related">
          <.link
            :for={content <- @posters}
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
            :if={@more_posters > 0}
            class="flex aspect-2/3 min-w-0 basis-12 items-center justify-center rounded-lg bg-surface text-sm font-semibold text-text-muted"
          >
            +{@more_posters}
          </span>
        </div>
      </div>
    </li>
    """
  end

  defp sentence(events, user, locale) do
    {watched, watching} = Enum.split_with(events, & &1.completed)
    user = gtspan(user.username, "font-semibold text-text")

    case {watching, watched} do
      {_watching, []} ->
        dgettext("home", "%{user} is watching %{contents}",
          user: user,
          contents: contents_part!(watching, locale)
        )

      {[], _watched} ->
        dgettext("home", "%{user} watched %{contents}",
          user: user,
          contents: contents_part!(watched, locale)
        )

      _both ->
        dgettext("home", "%{user} is watching %{watching}, and watched %{watched}",
          user: user,
          watching: contents_part!(watching, locale),
          watched: contents_part!(watched, locale)
        )
    end
    |> raw()
  end

  # "A", "A and B", "A, B, C, and 2 more", in the User's language
  defp contents_part!(events, locale) do
    {shown, more} = events |> Enum.map(&content_link(%{content: &1.content})) |> listed()

    shown
    |> Enum.map(&sentence_part/1)
    |> Enum.concat(
      if more > 0, do: [dngettext("home", "%{count} more", "%{count} more", more)], else: []
    )
    |> WatchClub.Cldr.List.to_string!(locale: UserLocale.to_cldr_locale_name(locale))
  end

  # The items to show and how many are left. "and 1 more" or "+1" would take the place of the item
  # it hides, so one extra item is shown instead.
  defp listed(items) when length(items) <= @listed_count + 1, do: {items, 0}
  defp listed(items), do: {Enum.take(items, @listed_count), length(items) - @listed_count}

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

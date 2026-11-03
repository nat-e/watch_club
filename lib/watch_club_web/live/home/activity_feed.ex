defmodule WatchClubWeb.Live.Home.ActivityFeed do
  @moduledoc """
  The Activity Feed of the Home page: its Feed Entries, latest first. Each entry is one sentence,
  such as "leadelpeut is watching WAR, Dune, and Fleabag, and watched Privileges".
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.ActivityFeed.FeedEntry
  alias WatchClubWeb.Helpers.KeysetStreamState

  # Sentences and posters show this many Contents or Clubs, then "and N more"
  @listed_count 3

  attr :stream, :list, required: true
  attr :stream_state, KeysetStreamState, required: true
  attr :current_user, User, required: true
  attr :instance_settings, InstanceSettings, required: true

  def activity_feed(assigns) do
    ~H"""
    <.section surface="transparent" padding="none" space="group" title={dgettext("feed", "Activity")}>
      <ol id="activity-feed" phx-update="stream" class="flex flex-col">
        <li id="activity-feed-empty-state" class="hidden only:block">
          <.empty_feed current_user={@current_user} instance_settings={@instance_settings} />
        </li>
        <.feed_entry
          :for={{dom_id, entry} <- @stream}
          id={dom_id}
          entry={entry}
          locale={@current_user.settings.locale}
        />
      </ol>

      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@stream_state)}
        id="activity-feed-load-more"
        event="load_activity_feed_page"
      />
    </.section>
    """
  end

  attr :current_user, User, required: true
  attr :instance_settings, InstanceSettings, required: true

  # The feed can be empty for the administrator when they just created the instance
  # Use this as an onboarding screen for prompting them to create a Club
  defp empty_feed(%{current_user: %User{administrator?: true}} = assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.rocket /></:icon>
      <:title>{dgettext("feed", "Welcome to Watch Club!")}</:title>
      <:description>
        {dgettext("feed", "Your instance is successfully installed!")}
        <br />{dgettext("feed", "Create a club and invite your friends to get started")}
      </:description>
      <.button
        id="empty-feed-create-club"
        variant="primary"
        phx-click={WatchClubWeb.Components.Clubs.ClubDialogsLive.open_create_club_modal()}
      >
        <:icon position="start"><Lucideicons.plus /></:icon>
        {dgettext("feed", "Create club")}
      </.button>
    </.empty>
    """
  end

  # The feed can also be empty for a user that is not a member of any club.
  defp empty_feed(assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.mail /></:icon>
      <:title>{dgettext("feed", "Welcome to %{name}!", name: @instance_settings.name)}</:title>
      <:description>
        {dgettext(
          "feed",
          "It's more fun with friends, contact the administrator so they can add you to some Clubs."
        )}
        <br />
        {dgettext(
          "feed",
          "In the mean time, you can still browse and watch some content on your own."
        )}
      </:description>
    </.empty>
    """
  end

  attr :id, :string, required: true
  attr :entry, FeedEntry, required: true
  attr :locale, :atom, required: true

  # The time sits on the left of the line, or under the sentence in a narrow page. The posters are
  # hidden from screen readers, because the sentence already links each Content.
  defp feed_entry(assigns) do
    contents =
      assigns.entry.scopes |> Enum.flat_map(&event_contents(&1.event)) |> Enum.uniq_by(& &1.id)

    {posters, more_posters} = listed(contents)

    assigns =
      assign(assigns,
        user: event_user(hd(assigns.entry.scopes).event),
        posters: posters,
        more_posters: more_posters
      )

    ~H"""
    <li id={@id} class="group/entry flex gap-related @xl:gap-group">
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
      <.avatar :if={@user} id={@user.id} name={@user.username} size="sm" aria-hidden="true" />
      <div class="flex min-w-0 flex-1 flex-col gap-related pb-cluster group-last/entry:pb-0">
        <div>
          <p class="text-sm text-text-muted">{sentence(@entry.scopes, @locale)}</p>
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
            class="block min-w-0 basis-20"
          >
            <.tmdb_poster
              size="w185"
              path={content.implementation.best_localization.poster_path}
              class="w-full"
            />
          </.link>
          <span
            :if={@more_posters > 0}
            class="flex aspect-2/3 min-w-0 basis-20 items-center justify-center rounded-lg bg-surface text-sm font-semibold text-text-muted"
          >
            +{@more_posters}
          </span>
        </div>
      </div>
    </li>
    """
  end

  # The scopes of an entry all hold the same kind of event, see SetGroupKey
  defp sentence([%{event: %ContentWatchedEvent{} = event} | _] = scopes, locale) do
    {watched, watching} = Enum.split_with(scopes, & &1.event.completed)
    user = user_part(event_user(event))

    case {watching, watched} do
      {_watching, []} ->
        dgettext("feed", "%{user} is watching %{contents}",
          user: user,
          contents: contents_part!(watching, locale)
        )

      {[], _watched} ->
        dgettext("feed", "%{user} watched %{contents}",
          user: user,
          contents: contents_part!(watched, locale)
        )

      _both ->
        dgettext("feed", "%{user} is watching %{watching}, and watched %{watched}",
          user: user,
          watching: contents_part!(watching, locale),
          watched: contents_part!(watched, locale)
        )
    end
    |> raw()
  end

  defp sentence([%{event: %ContentAddedEvent{} = event} = scope | _] = scopes, locale) do
    raw(
      dgettext("feed", "%{user} added %{contents} to %{club}",
        user: user_part(event_user(event)),
        contents: contents_part!(scopes, locale),
        club: sentence_part(club_link(%{club: scope.scope_club, avatar: true}))
      )
    )
  end

  defp sentence([%{event: %MemberAddedEvent{} = event} | _] = scopes, locale) do
    clubs = Enum.map(scopes, &sentence_part(club_link(%{club: &1.scope_club})))

    raw(
      dgettext("feed", "%{user} joined %{clubs}",
        user: user_part(event_user(event)),
        clubs: list_part!(clubs, locale)
      )
    )
  end

  defp sentence([%{event: %ClubCreatedEvent{} = event}], _locale) do
    raw(
      dgettext("feed", "%{user} created the club %{club}",
        user: user_part(event_user(event)),
        club: sentence_part(club_link(%{club: event.club}))
      )
    )
  end

  defp sentence([%{event: %LibraryCreatedEvent{} = event} = scope], _locale) do
    raw(
      dgettext("feed", "%{user} created the library %{library} in %{club}",
        user: user_part(event_user(event)),
        library: sentence_part(library_link(%{library: event.library})),
        club: sentence_part(club_link(%{club: scope.scope_club}))
      )
    )
  end

  defp user_part(%User{username: username}), do: gtspan(username, "font-semibold text-text")
  defp user_part(nil), do: gtspan(dgettext("default", "Deleted user"), "font-semibold text-text")

  defp contents_part!(scopes, locale) do
    scopes
    |> Enum.flat_map(&event_contents(&1.event))
    |> Enum.uniq_by(& &1.id)
    |> Enum.map(&sentence_part(content_link(%{content: &1})))
    |> list_part!(locale)
  end

  # "A", "A and B", "A, B, C, and D", "A, B, C, and 2 more", in the user's language
  defp list_part!(items, locale) do
    {shown, more} = listed(items)

    shown
    |> Enum.concat(
      if more > 0, do: [dngettext("feed", "%{count} more", "%{count} more", more)], else: []
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

  attr :club, Club, required: true
  attr :avatar, :boolean, default: false

  # The avatar is hidden from screen readers, because the name follows it
  defp club_link(assigns) do
    ~H"""
    <.link
      navigate={Url.club_link(@club)}
      class="inline-flex items-center gap-tight align-bottom font-semibold text-accent hover:underline"
    >
      <.avatar :if={@avatar} id={@club.id} name={@club.name} size="sm" aria-hidden="true" />
      <span>{@club.name}</span>
    </.link>
    """
  end

  attr :library, Library, required: true

  defp library_link(assigns) do
    ~H"""
    <.link
      navigate={Url.club_library_link(@library)}
      class="font-semibold text-accent hover:underline"
    >
      {@library.name}
    </.link>
    """
  end

  defp event_user(%MemberAddedEvent{membership: membership}), do: membership.user
  defp event_user(event), do: event.actor

  defp event_contents(%ContentWatchedEvent{content: content}), do: [content]
  defp event_contents(%ContentAddedEvent{library_item: library_item}), do: [library_item.content]
  defp event_contents(_event), do: []
end

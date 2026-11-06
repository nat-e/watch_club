defmodule WatchClubWeb.Components.Conversations.Recipients do
  @moduledoc """
  Who a Content was recommended to in a Conversation: their avatars, then their names, the User
  first as "you", deleted Users last.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Accounts.UserAvatar

  alias WatchClub.Conversations.Conversation

  attr :conversation, Conversation, required: true, doc: "with its `recipients` and their `user`"
  attr :current_user, User, required: true
  attr :ring, :string, default: "ring-canvas", doc: "the avatars' ring: the surface they're on"
  attr :class, :any, default: nil

  def recipients(assigns) do
    {users, deleted} =
      assigns.conversation.recipients
      |> Enum.map(& &1.user)
      |> Enum.split_with(& &1)

    {you, others} = Enum.split_with(users, &(&1.id == assigns.current_user.id))
    users = you ++ Enum.sort_by(others, & &1.username)

    names =
      Enum.map(users, &if(&1 in you, do: dgettext("conversations", "you"), else: &1.username)) ++
        Enum.map(deleted, fn _user -> username(nil) end)

    assigns =
      assign(assigns,
        avatars: Enum.map(users, &%{id: &1.id, name: &1.username}),
        deleted?: deleted != [],
        names:
          WatchClub.Cldr.List.to_string!(names,
            locale: UserLocale.to_cldr_locale_name(assigns.current_user.settings.locale)
          )
      )

    ~H"""
    <span class={@class}>
      <span class="mr-tight inline-flex shrink-0 items-center align-middle">
        <.avatar_group
          :if={@avatars != []}
          avatars={@avatars}
          avatar_size="sm"
          avatar_class={["ring-2", @ring]}
          class="-space-x-1.5!"
        />
        <.user_avatar :if={@deleted?} size="sm" class={["ring-2", @avatars != [] && "-ml-1.5", @ring]} />
      </span>{@names}
    </span>
    """
  end
end

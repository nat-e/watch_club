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
    users = you ++ Enum.sort_by(others, & &1.username) ++ deleted

    names =
      Enum.map(users, &if(&1 in you, do: dgettext("conversations", "you"), else: username(&1)))

    assigns =
      assign(assigns,
        avatars: Enum.map(users, &%{id: &1 && &1.id, name: username(&1)}),
        names:
          WatchClub.Cldr.List.to_string!(names,
            locale: UserLocale.to_cldr_locale_name(assigns.current_user.settings.locale)
          )
      )

    ~H"""
    <span class={@class}>
      <%!-- The names follow --%>
      <span aria-hidden="true" class="mr-tight inline-flex shrink-0 items-center align-middle">
        <.avatar_group
          avatars={@avatars}
          avatar_size="sm"
          avatar_class={["ring-2", @ring]}
          class="-space-x-1.5!"
        />
      </span>{@names}
    </span>
    """
  end
end

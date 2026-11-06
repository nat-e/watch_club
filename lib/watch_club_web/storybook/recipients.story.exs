defmodule WatchClubWeb.Storybook.Recipients do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.{User, UserSettings}
  alias WatchClub.Conversations.{Conversation, Participant}
  alias WatchClubWeb.Components.Conversations.Recipients

  def function, do: &Recipients.recipients/1

  def template do
    """
    <div class="p-4 text-sm text-text-muted">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :to_you,
        description: ~s(The User first, as "you"),
        attributes: %{
          conversation: conversation(["vinz", "leloup"]),
          current_user: you()
        }
      },
      %Variation{
        id: :deleted_user,
        description: "A deleted User, last",
        attributes: %{
          conversation: conversation(["vinz", nil]),
          current_user: you()
        }
      }
    ]
  end

  defp you, do: %User{id: "you", username: "you", settings: %UserSettings{locale: :en_US}}

  defp conversation(usernames) do
    recipients =
      Enum.map([you() | Enum.map(usernames, &user/1)], fn user ->
        %Participant{user_id: user && user.id, user: user}
      end)

    %Conversation{id: "conversation", recipients: recipients}
  end

  defp user(nil), do: nil
  defp user(username), do: %User{id: "user-#{username}", username: username}
end

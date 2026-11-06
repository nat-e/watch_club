defmodule WatchClubWeb.Helpers.Usernames do
  @moduledoc """
  Users named in a sentence, in the current User's locale.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.{User, UserLocale}

  @doc """
  The Users' names as a list in a sentence, the current User as "you": "leadelpeut, guigui74
  and you".
  """
  def join(users, %User{} = current_user) do
    users
    |> Enum.map(&if(&1.id == current_user.id, do: dgettext("default", "you"), else: &1.username))
    |> WatchClub.Cldr.List.to_string!(
      locale: UserLocale.to_cldr_locale_name(current_user.settings.locale)
    )
  end
end

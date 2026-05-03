defmodule WatchClubWeb.Components do
  defmacro __using__(_opts) do
    quote do
      import WatchClubWeb.Components.Accounts.RegistrationForm
      import WatchClubWeb.Components.Accounts.SignInForm
      import WatchClubWeb.Components.Clubs
      import WatchClubWeb.Components.Forms
      import WatchClubWeb.Components.Modals
      import WatchClubWeb.Components.Nav
    end
  end
end

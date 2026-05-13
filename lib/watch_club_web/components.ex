defmodule WatchClubWeb.Components do
  defmacro __using__(_opts) do
    quote do
      import WatchClubWeb.Components.Accounts.RegistrationForm
      import WatchClubWeb.Components.Accounts.SignInForm
      import WatchClubWeb.Components.Contents
      import WatchClubWeb.Components.EditableLabel
      import WatchClubWeb.Components.Images
      import WatchClubWeb.Components.ReorderableList
      import WatchClubWeb.Components.Settings
    end
  end
end

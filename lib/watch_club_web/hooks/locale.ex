defmodule WatchClubWeb.Hooks.Locale do
  import Phoenix.LiveView

  require Logger

  alias WatchClub.Accounts.UserSettings

  def on_mount(:default, _params, session, socket) do
    locale =
      case socket.assigns.current_user do
        nil ->
          session["browser_locale"]

        user ->
          user.settings.locale
      end

    language = extract_language(locale)
    Logger.info("Set language to #{language}")
    Gettext.put_locale(WatchClubWeb.Gettext, language)

    {:cont,
     socket
     |> attach_hook(
       :reload_locale_on_change,
       :handle_info,
       &reload_locale_on_change/2
     )}
  end

  defp reload_locale_on_change(
         %Ash.Notifier.Notification{
           resource: UserSettings,
           action: %Ash.Resource.Actions.Update{},
           data: %UserSettings{locale: locale}
         },
         socket
       ) do
    language = extract_language(locale)
    Logger.info("Set language to #{language}")
    Gettext.put_locale(WatchClubWeb.Gettext, language)
    {:cont, socket}
  end

  defp reload_locale_on_change(_notification, socket) do
    {:cont, socket}
  end

  defp extract_language(locale) do
    Atom.to_string(locale) |> String.split("_") |> List.first()
  end
end

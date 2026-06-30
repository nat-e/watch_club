defmodule WatchClubWeb.Hooks.Locale do
  import Phoenix.LiveView

  require Logger

  alias WatchClub.Accounts.UserSettings
  alias WatchClubWeb.Helpers.Url

  def on_mount(:default, _params, session, socket) do
    locale =
      case socket.assigns.current_user do
        nil ->
          session["browser_locale"]

        user ->
          user.settings.locale
      end

    language = extract_language(locale)
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

    if Gettext.get_locale(WatchClubWeb.Gettext) == language do
      {:cont, socket}
    else
      Logger.info("language changed", language: language)
      Gettext.put_locale(WatchClubWeb.Gettext, language)
      {:halt, push_navigate(socket, to: current_path(socket.assigns.current_url), replace: true)}
    end
  end

  defp reload_locale_on_change(_notification, socket) do
    {:cont, socket}
  end

  defp extract_language(locale) do
    Atom.to_string(locale) |> String.split("_") |> List.first()
  end

  defp current_path(%Url{path: path, query: query}) when query == %{}, do: path

  defp current_path(%Url{path: path, query: query}) do
    path <> "?" <> URI.encode_query(query)
  end
end

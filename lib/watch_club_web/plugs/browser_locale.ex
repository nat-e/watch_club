defmodule WatchClubWeb.Plugs.BrowserLocale do
  @moduledoc """
  A Plug that reads the Accept-Language header and sets it in the session
  """
  import Plug.Conn

  alias WatchClub.Accounts.UserLocale

  # AcceptLanguage matches language tags such as `:"fr-FR"`, not locales such as `:fr_FR`
  @locales_by_tag Map.new(UserLocale.values(), fn locale ->
                    {locale |> Atom.to_string() |> String.replace("_", "-") |> String.to_atom(),
                     locale}
                  end)
  @default_locale UserLocale.default()

  @spec get(map()) :: :atom
  def get(session), do: session["browser_locale"]

  def init(default) do
    default
  end

  def call(conn, _default) do
    browser_locale = conn |> get_req_header("accept-language") |> List.first() |> negotiate()

    # Controller/error-page rendering happens in the Plug request process, while
    # LiveViews run in their own processes and set the same effective locale in
    # `WatchClubWeb.Hooks.Locale`.
    locale =
      case conn.assigns.current_user do
        nil -> browser_locale
        user -> user.settings.locale
      end

    language = locale |> Atom.to_string() |> String.split("_") |> List.first()
    Gettext.put_locale(WatchClubWeb.Gettext, language)

    conn |> put_session(:browser_locale, browser_locale)
  end

  defp negotiate(nil), do: @default_locale

  defp negotiate(header) do
    case AcceptLanguage.negotiate(header, Map.keys(@locales_by_tag)) do
      nil -> @default_locale
      tag -> @locales_by_tag[tag]
    end
  end
end

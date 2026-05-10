defmodule WatchClubWeb.Plugs.BrowserLocale do
  @moduledoc """
  A Plug that reads the Accept-Language header and sets it in the session
  """
  import Plug.Conn

  alias WatchClub.Accounts.UserLocale

  @locales UserLocale.values()
  @default_locale List.first(UserLocale.values())

  @spec get(map()) :: :atom
  def get(session), do: session["browser_locale"]

  def init(default) do
    default
  end

  def call(conn, _default) do
    locale = conn |> get_req_header("accept-language") |> List.first() |> negotiate()
    conn |> put_session(:browser_locale, locale)
  end

  defp negotiate(nil), do: @default_locale

  defp negotiate(header) do
    case AcceptLanguage.negotiate(header, @locales) do
      nil -> @default_locale
      locale -> locale
    end
  end
end

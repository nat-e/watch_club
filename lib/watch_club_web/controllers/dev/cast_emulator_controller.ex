# Only in development, like its routes
if Application.compile_env(:watch_club, :dev_routes) do
  defmodule WatchClubWeb.Dev.CastEmulatorController do
    @moduledoc """
    The Cast emulator, in development: Chrome casts to a TV that it opens in a window, which plays
    WatchClub's receiver page. See `@mattiasbuelens/chromecast-emulator` in `assets/package.json`.
    """
    use WatchClubWeb, :controller

    @scripts ~w(presentation-polyfill.js cast-sender-emulator.js cast-receiver-emulator.js)

    @doc "WatchClub's receiver page, with the emulator's scripts before Google's receiver framework."
    def receiver(conn, _params) do
      emulator =
        ~s(<script src="#{~p"/dev/cast/emulator/presentation-polyfill.js"}"></script>) <>
          ~s(<script src="#{~p"/dev/cast/emulator/cast-receiver-emulator.js"}"></script>)

      page =
        File.cwd!()
        |> Path.join("cast_receiver/index.html")
        |> File.read!()
        |> String.replace("<!-- cast emulator -->", emulator)

      html(conn, page)
    end

    def script(conn, %{"file" => file}) when file in @scripts do
      conn
      |> put_resp_content_type("text/javascript")
      |> send_file(
        200,
        Path.join(
          File.cwd!(),
          "assets/node_modules/@mattiasbuelens/chromecast-emulator/dist/#{file}"
        )
      )
    end
  end
end

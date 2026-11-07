defmodule WatchClubWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext), your module compiles translations
  that you can use in your application. To use this Gettext backend module,
  call `use Gettext` and pass it as an option:

      use Gettext, backend: WatchClubWeb.Gettext

      # Simple translation
      gettext("Here is the string to translate")

      # Plural translation
      ngettext("Here is the string to translate",
               "Here are the strings to translate",
               3)

      # Domain-based translation
      dgettext("errors", "Here is the error message to translate")

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext.Backend,
    otp_app: :watch_club,
    default_locale: :en_US

  defmodule Helpers do
    def gtspan(text, class \\ "") do
      text
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()
      |> then(&~s(<span class="#{class}">#{&1}</span>))
    end

    def gtbold(text) do
      text
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()
      |> then(&~s(<span class="font-semibold">#{&1}</span>))
    end

    @doc """
    Renders a function component to HTML, to embed it in a translated sentence with `raw/1`.

        raw(dgettext("feed", "%{user} recommended this content", user: gtcomponent(user_ref(%{user: user}))))
    """
    def gtcomponent(rendered) do
      rendered
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()
    end
  end
end

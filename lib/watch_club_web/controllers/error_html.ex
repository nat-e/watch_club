defmodule WatchClubWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use WatchClubWeb, :html

  @doc """
  Renders minimal, self-contained error pages.

  Error pages intentionally do not use the application layout to avoid circular
  failures if the layout itself is involved in the original exception.
  """
  def render(template, assigns) do
    assigns =
      Map.merge(assigns, %{
        __changed__: nil,
        status: status_from_template(template),
        title: title_from_template(template),
        description: description_from_template(template),
        retry?: retryable_template?(template),
        instance_name: assigns.instance_settings.name
      })

    ~H"""
    <!DOCTYPE html>
    <html lang={Gettext.get_locale(WatchClubWeb.Gettext)} class="theme-wc dark">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{@title} · {@instance_name}</title>
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body class="min-h-svh bg-canvas text-text">
        <main class="flex min-h-svh items-center justify-center px-page py-page-y">
          <section class="flex w-full max-w-readable flex-col gap-group text-center text-balance">
            <p class="text-sm font-semibold tracking-wide text-text-muted">{@status}</p>
            <div class="flex flex-col gap-related">
              <h1 class="text-2xl font-bold tracking-tight text-text sm:text-3xl">
                {@title}
              </h1>
              <p class="text-sm/relaxed text-text-muted sm:text-base/relaxed">
                {@description}
              </p>
            </div>
            <div class="flex flex-wrap justify-center gap-related">
              <.button
                :if={@retry?}
                id="error-page-retry-button"
                href={Phoenix.Controller.current_path(@conn)}
                emphasis
              >
                {dgettext("default", "Try again")}
              </.button>
              <.button
                id="error-page-home-button"
                href={~p"/"}
                variant={if @retry?, do: "secondary", else: "primary"}
                emphasis={!@retry?}
              >
                {dgettext("default", "Go home")}
              </.button>
            </div>
          </section>
        </main>
      </body>
    </html>
    """
  end

  defp status_from_template(template) do
    template
    |> String.split(".", parts: 2)
    |> List.first()
  end

  defp retryable_template?(template) do
    template
    |> status_from_template()
    |> String.starts_with?("5")
  end

  defp title_from_template("400.html"), do: dgettext("default", "Page not found")
  defp title_from_template("403.html"), do: dgettext("default", "Page not found")
  defp title_from_template("404.html"), do: dgettext("default", "Page not found")
  defp title_from_template(_template), do: dgettext("default", "Could not load page")

  defp description_from_template("400.html"),
    do:
      dgettext(
        "default",
        "The page you are looking for does not exist or you do not have access to it."
      )

  defp description_from_template("403.html") do
    dgettext(
      "default",
      "The page you are looking for does not exist or you do not have access to it."
    )
  end

  defp description_from_template("404.html") do
    dgettext(
      "default",
      "The page you are looking for does not exist or you do not have access to it."
    )
  end

  defp description_from_template(_template) do
    dgettext("default", "Something went wrong while loading this page.")
  end
end

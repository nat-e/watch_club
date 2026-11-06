defmodule WatchClubWeb.Contents.ContentPage.CastSection do
  @moduledoc """
  The director and the actors of a Movie or a TV Show.
  """
  use WatchClubWeb, :component

  alias WatchClub.Integrations.Tmdb.Types.Credits

  attr :credits, Credits, required: true

  # Like Who watched it: a heading, then round photos in a row that scrolls sideways
  def cast_section(assigns) do
    assigns = assigns |> assign(cast_and_crew: cast_and_crew(assigns.credits))

    ~H"""
    <section
      :if={@cast_and_crew != []}
      aria-labelledby="cast-heading"
      class="flex min-w-0 flex-col gap-group"
    >
      <h2 id="cast-heading" class="font-heading text-xl font-semibold">
        {dgettext("contents", "Cast")}
      </h2>
      <.scroll_row id="cast">
        <.cast_member :for={person <- @cast_and_crew} person={person} />
      </.scroll_row>
    </section>
    """
  end

  attr :person, :map, required: true

  # Their photo, or their initials, then their name and their role
  defp cast_member(assigns) do
    ~H"""
    <div class="flex w-24 shrink-0 snap-start flex-col items-center gap-related text-center">
      <span class="relative size-20 shrink-0 overflow-hidden rounded-full bg-surface-raised">
        <img
          :if={@person.profile_path}
          src={tmdb_profile_url(@person.profile_path)}
          alt=""
          loading="lazy"
          class="absolute inset-0 size-full object-cover"
        />
        <span
          :if={!@person.profile_path}
          class="absolute inset-0 flex items-center justify-center text-sm font-semibold text-text-muted"
        >
          {@person.initials}
        </span>
      </span>
      <span class="flex w-full flex-col">
        <span class="line-clamp-2 text-sm font-semibold">{@person.name}</span>
        <span class="line-clamp-2 text-xs text-text-muted">{@person.role}</span>
      </span>
    </div>
    """
  end

  defp cast_and_crew(credits) do
    cast = (credits && credits.cast) || []
    crew = (credits && credits.crew) || []

    directors =
      crew
      |> Enum.filter(&(&1.job == "Director"))
      |> Enum.take(1)

    actors =
      cast
      |> Enum.sort_by(&(&1.order || 999_999))
      |> Enum.take(17)

    (directors ++ actors)
    |> Enum.uniq_by(&(&1.id || &1.name))
    |> Enum.take(18)
    |> Enum.map(fn credit ->
      %{
        name: credit.name,
        role: credit.character || credit.job,
        initials: initials(credit.name),
        profile_path: credit.profile_path
      }
    end)
  end

  defp initials(nil), do: nil

  defp initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
  end

  defp tmdb_profile_url(path), do: "https://image.tmdb.org/t/p/w185#{path}"
end

defmodule WatchClubWeb.Components.Contents.Details.CastSection do
  @moduledoc """
  Cast & crew section shared by the Movie and TV Show detail pages.
  """
  use WatchClubWeb, :component

  alias WatchClub.Integrations.Tmdb.Types.Credits

  attr :credits, Credits, required: true

  def cast_section(assigns) do
    assigns = assigns |> assign(cast_and_crew: cast_and_crew(assigns.credits))

    ~H"""
    <.section
      :if={@cast_and_crew != []}
      title={dgettext("contents", "Cast")}
      icon={:users}
    >
      <ul class="flex max-h-[calc(33.5rem+var(--wc-space-group)+var(--wc-space-tight))] flex-wrap justify-center gap-group overflow-hidden sm:max-h-[calc(36.5rem+var(--wc-space-group)+var(--wc-space-tight))] sm:justify-start">
        <.cast_card :for={person <- @cast_and_crew} person={person} />
      </ul>
    </.section>
    """
  end

  attr :person, :map, required: true

  defp cast_card(assigns) do
    ~H"""
    <li class="grid w-28 shrink-0 grid-rows-[10.5rem_6.25rem] overflow-hidden rounded-xl border border-border-subtle bg-surface-inset shadow-card sm:w-32 sm:grid-rows-[12rem_6.25rem]">
      <div class="relative bg-surface-raised">
        <img
          :if={@person.profile_path}
          src={tmdb_profile_url(@person.profile_path)}
          alt=""
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div
          :if={!@person.profile_path}
          class="absolute inset-0 grid place-items-center text-lg font-semibold text-accent"
        >
          {@person.initials}
        </div>
      </div>
      <.stack space="tight" class="overflow-hidden p-related">
        <p class="text-sm leading-5 font-semibold wrap-break-words text-text">{@person.name}</p>
        <p class="line-clamp-1 text-xs leading-5 wrap-break-words text-text-muted">{@person.role}</p>
      </.stack>
    </li>
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

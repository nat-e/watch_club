defmodule WatchClubWeb.UI.Avatar do
  @moduledoc """
  Token-driven Watch Club avatar primitive.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true

  attr :size, :string,
    values: ~w(xs sm md lg),
    default: "md"

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(title aria-label)

  def avatar(assigns) do
    assigns =
      assigns
      |> assign(:background_class, background_class(assigns.id))
      |> assign(:initial, initial(assigns.name))

    ~H"""
    <span
      role="img"
      aria-label={@name}
      title={@name}
      class={[
        "relative flex shrink-0 items-center justify-center rounded-full border border-border font-bold text-white select-none",
        avatar_size_class(@size),
        @background_class,
        @class
      ]}
      {@rest}
    >
      {@initial}
    </span>
    """
  end

  attr :avatars, :list, required: true
  attr :class, :any, default: nil

  attr :avatar_size, :string,
    values: ~w(xs sm md lg),
    default: "md"

  attr :avatar_class, :any, default: nil
  attr :rest, :global

  def avatar_group(assigns) do
    visible_avatars =
      if length(assigns.avatars) <= 3, do: assigns.avatars, else: Enum.take(assigns.avatars, 2)

    assigns =
      assigns
      |> assign(:visible_avatars, visible_avatars)
      |> assign(:overflow_count, length(assigns.avatars) - length(visible_avatars))

    ~H"""
    <div class={["flex items-center -space-x-4", @class]} {@rest}>
      <.avatar
        :for={avatar <- @visible_avatars}
        id={avatar.id}
        name={avatar.name}
        size={@avatar_size}
        class={["ring-2 ring-background", @avatar_class]}
      />
      <span
        :if={@overflow_count > 0}
        aria-label={"#{@overflow_count} more"}
        class={[
          "relative flex shrink-0 items-center justify-center rounded-full border border-border bg-gray-500 font-bold text-white ring-2 ring-background select-none",
          avatar_size_class(@avatar_size),
          @avatar_class
        ]}
      >
        +{@overflow_count}
      </span>
    </div>
    """
  end

  defp avatar_size_class("xs"), do: "size-5 text-[0.625rem] leading-none"
  defp avatar_size_class("sm"), do: "size-6 text-xs leading-none"
  defp avatar_size_class("md"), do: "size-8 text-base"
  defp avatar_size_class("lg"), do: "size-10 text-lg"

  defp initial(name) do
    name
    |> String.trim()
    |> String.first()
    |> String.upcase()
  end

  defp background_class(id) when is_binary(id) do
    colors = {
      "bg-blue-500",
      "bg-emerald-500",
      "bg-amber-500",
      "bg-red-500",
      "bg-violet-500",
      "bg-cyan-500",
      "bg-lime-500",
      "bg-orange-500",
      "bg-pink-500",
      "bg-indigo-500",
      "bg-teal-500",
      "bg-purple-500",
      "bg-green-500",
      "bg-rose-500",
      "bg-sky-500",
      "bg-lime-600",
      "bg-red-600",
      "bg-violet-600",
      "bg-emerald-600",
      "bg-amber-600"
    }

    elem(colors, :erlang.phash2(id, tuple_size(colors)))
  end
end

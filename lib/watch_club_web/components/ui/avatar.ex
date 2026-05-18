defmodule WatchClubWeb.Components.UI.Avatar do
  @moduledoc """
  Token-driven Watch Club avatar primitive.
  """

  use Phoenix.Component
  use Gettext, backend: WatchClubWeb.Gettext

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
        "relative flex shrink-0 items-center justify-center rounded-full font-bold text-white select-none",
        @size == "xs" && "size-5 text-[0.625rem] leading-none",
        @size == "sm" && "size-6 text-xs leading-none",
        @size == "md" && "size-8 text-base",
        @size == "lg" && "size-10 text-lg",
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
        class={@avatar_class}
      />
      <span
        :if={@overflow_count > 0}
        aria-label={dgettext("default", "%{count} more", count: @overflow_count)}
        class={[
          "relative flex shrink-0 items-center justify-center rounded-full border border-border bg-surface-raised font-bold text-text select-none",
          @avatar_size == "xs" && "size-5 text-[0.625rem] leading-none",
          @avatar_size == "sm" && "size-6 text-xs leading-none",
          @avatar_size == "md" && "size-8 text-base",
          @avatar_size == "lg" && "size-10 text-lg",
          @avatar_class
        ]}
      >
        +{@overflow_count}
      </span>
    </div>
    """
  end

  defp initial(name) do
    name
    |> String.trim()
    |> String.first()
    |> String.upcase()
  end

  defp background_class(id) when is_binary(id) do
    # Intentional design-system exception: avatar identity colors are generated
    # deterministically to help distinguish users and clubs. Keep raw palette
    # colors encapsulated in this primitive; product code should use semantic tokens.
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

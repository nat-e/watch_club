defmodule Shadcn.Components.Avatar do
  @moduledoc """
  Image element with a fallback for representing the user.

      <.avatar id="user-jane">
        <:image src="/images/jane.png" alt="Jane Doe" />
        <:fallback>JD</:fallback>
      </.avatar>

      <.avatar size="lg">
        <:fallback>JD</:fallback>
      </.avatar>

      <.avatar id="user-jane">
        <:image src="/images/jane.png" alt="Jane Doe" />
        <:fallback delay_ms={600}>JD</:fallback>
        <:badge><Lucideicons.check /></:badge>
      </.avatar>

  Both `:image` and `:fallback` can be declared together — the fallback
  paints on the server, then the `AvatarHook` (in `avatar.js` next to
  this file, registered via `assets/js/components.js`) swaps in the image
  once it loads (or keeps the fallback if the image errors). Pass `id`
  for the hook to attach. Without `id` (or with JS disabled), the image
  renders normally over the fallback.

  Set `delay_ms` on the fallback to defer its appearance, avoiding a
  flash on fast connections (mirrors Radix's `Avatar.Fallback#delayMs`).

  Ported from Shadcn on 2026-04-28
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/avatar.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/avatar
  Radix doc: https://www.radix-ui.com/primitives/docs/components/avatar
  """
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :size, :string, values: ~w(sm default lg), default: "default"
  attr :rest, :global

  slot :image do
    attr :src, :string, required: true
    attr :alt, :string
    attr :class, :any
  end

  slot :fallback do
    attr :class, :any
    attr :delay_ms, :integer
  end

  slot :badge do
    attr :class, :any
  end

  def avatar(assigns) do
    delay_ms = List.first(assigns.fallback)[:delay_ms]
    hooked? = assigns.id && assigns.image != []

    initial_status =
      cond do
        hooked? && delay_ms -> "loading-delayed"
        hooked? -> "loading"
        true -> nil
      end

    assigns =
      assigns
      |> assign(:status, initial_status)
      |> assign(:delay_ms, delay_ms)
      |> assign(:hooked?, hooked?)

    ~H"""
    <span
      id={@id}
      data-slot="avatar"
      data-size={@size}
      data-status={@status}
      data-fallback-delay={@delay_ms}
      phx-hook={@hooked? && "AvatarHook"}
      class={["group/avatar", @class]}
      {@rest}
    >
      <span :for={f <- @fallback} data-slot="avatar-fallback" class={f[:class]}>
        {render_slot(f)}
      </span>
      <img
        :for={i <- @image}
        data-slot="avatar-image"
        src={i.src}
        alt={i[:alt]}
        class={i[:class]}
      />
      <span :for={b <- @badge} data-slot="avatar-badge" class={b[:class]}>
        {render_slot(b)}
      </span>
    </span>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :count do
    attr :class, :any
  end

  slot :inner_block, required: true

  def avatar_group(assigns) do
    ~H"""
    <div data-slot="avatar-group" class={["group/avatar-group", @class]} {@rest}>
      {render_slot(@inner_block)}
      <div :for={c <- @count} data-slot="avatar-group-count" class={c[:class]}>
        {render_slot(c)}
      </div>
    </div>
    """
  end
end

defmodule Shadcn.Storybook.Drawer do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Drawer

  def function, do: &Drawer.drawer/1
  def imports, do: [{Shadcn.Components.Button, [button: 1]}]

  @lorem """
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod \
  tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim \
  veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea \
  commodo consequat.\
  """

  defp scrollable_paragraphs do
    1..10
    |> Enum.map_join("\n", fn _ -> ~s|<p class="leading-normal">#{@lorem}</p>| end)
  end

  # Inline onclick that increments/decrements the displayed goal,
  # clamped to [200, 400], and toggles the disabled state on the buttons.
  # Uses dataset lookups to avoid nested double-quoted attribute selectors.
  @move_goal_step_js """
  (function(btn,delta){\
  var root=btn.closest('[data-move-goal]');\
  var display=root.querySelector('[data-move-goal-value]');\
  var v=Math.max(200,Math.min(400,parseInt(display.textContent,10)+delta));\
  display.textContent=v;\
  root.querySelectorAll('button[data-move-goal-step]').forEach(function(b){\
  var d=parseInt(b.dataset.moveGoalStep,10);\
  b.disabled=(d<0&&v<=200)||(d>0&&v>=400);\
  });\
  })\
  """

  defp move_goal_body do
    """
    <div class="mx-auto w-full max-w-sm" data-move-goal>
      <div class="flex items-center justify-center gap-2 p-4 pb-0">
        <.button
          variant="outline"
          size="icon"
          class="size-8 shrink-0 rounded-full"
          data-move-goal-step="-10"
          onclick="#{@move_goal_step_js}(this,-10)"
        >
          <span aria-hidden="true">−</span>
          <span class="sr-only">Decrease</span>
        </.button>
        <div class="flex-1 text-center">
          <div class="text-7xl font-bold tracking-tighter" data-move-goal-value>350</div>
          <div class="text-[0.70rem] uppercase text-muted-foreground">Calories/day</div>
        </div>
        <.button
          variant="outline"
          size="icon"
          class="size-8 shrink-0 rounded-full"
          data-move-goal-step="10"
          onclick="#{@move_goal_step_js}(this,10)"
        >
          <span aria-hidden="true">+</span>
          <span class="sr-only">Increase</span>
        </.button>
      </div>
      <div class="mt-3 flex h-[120px] items-end justify-between gap-1 px-1">
        <div class="w-full rounded-sm bg-foreground/90" style="height: 80%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 60%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 40%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 60%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 40%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 56%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 38%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 48%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 60%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 40%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 56%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 38%"></div>
        <div class="w-full rounded-sm bg-foreground/90" style="height: 70%"></div>
      </div>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Move Goal — counter with +/- controls (matches the shadcn main demo)",
        attributes: %{id: "drawer-default"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open Drawer</.button></:trigger>|,
          ~s|<:title class="mx-auto w-full max-w-sm">Move Goal</:title>|,
          ~s|<:description class="mx-auto w-full max-w-sm">Set your daily activity goal.</:description>|,
          move_goal_body(),
          """
          <:footer class="mx-auto w-full max-w-sm">
            <.button>Submit</.button>
            <.button data-drawer-close variant="outline">Cancel</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :direction_top,
        description: ~s|direction="top" — slides in from the top edge|,
        attributes: %{id: "drawer-top", direction: "top"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open from top</.button></:trigger>|,
          ~s|<:title>Notifications</:title>|,
          ~s|<:description>You have 3 unread updates.</:description>|,
          ~s|<p class="px-4 pb-4">Latest activity appears here.</p>|,
          ~s|<:footer><.button data-drawer-close variant="outline">Dismiss</.button></:footer>|
        ]
      },
      %Variation{
        id: :direction_right,
        description: ~s|direction="right" — slides in from the right edge|,
        attributes: %{id: "drawer-right", direction: "right"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open from right</.button></:trigger>|,
          ~s|<:title>Filters</:title>|,
          ~s|<:description>Refine the visible items.</:description>|,
          ~s|<p class="px-4 pb-4">Filter controls go here.</p>|,
          """
          <:footer>
            <.button>Apply</.button>
            <.button data-drawer-close variant="outline">Cancel</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :direction_left,
        description: ~s|direction="left" — slides in from the left edge|,
        attributes: %{id: "drawer-left", direction: "left"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open from left</.button></:trigger>|,
          ~s|<:title>Navigation</:title>|,
          ~s|<:description>Jump to a section.</:description>|,
          ~s|<p class="px-4 pb-4">Nav links go here.</p>|
        ]
      },
      %Variation{
        id: :scrollable_content,
        description: "Scrollable content — long body scrolls, footer stays pinned",
        attributes: %{id: "drawer-scrollable"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open scrollable</.button></:trigger>|,
          ~s|<:title>Terms of Service</:title>|,
          ~s|<:description>Please review the details below.</:description>|,
          ~s|<div class="mx-auto flex w-full max-w-sm flex-col gap-4 pb-4">#{scrollable_paragraphs()}</div>|,
          """
          <:footer class="mx-auto w-full max-w-sm">
            <.button data-drawer-close>Close</.button>
          </:footer>
          """
        ]
      }
    ]
  end
end

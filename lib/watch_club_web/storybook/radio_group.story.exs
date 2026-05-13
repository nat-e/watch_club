defmodule WatchClubWeb.Storybook.RadioGroup do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.UI.RadioGroup

  def function, do: &RadioGroup.radio_group/1

  def imports do
    [
      {WatchClubWeb.Components.Contents, [content_type_icon: 1]},
      {Lucideicons, [check: 1]}
    ]
  end

  defp container_template(content) do
    """
    <div class="w-full max-w-md p-4 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default stacked radio group",
        attributes: %{name: "plan", value: "club"},
        slots: [
          ~s(<:item value="solo">Solo watcher</:item>),
          ~s(<:item value="club">Club member</:item>),
          ~s(<:item value="host">Club host</:item>)
        ]
      },
      %Variation{
        id: :empty,
        description: "Nothing selected",
        attributes: %{name: "cadence"},
        slots: [
          ~s(<:item value="weekly">Weekly</:item>),
          ~s(<:item value="monthly">Monthly</:item>),
          ~s(<:item value="seasonal">Seasonal</:item>)
        ]
      },
      %Variation{
        id: :with_disabled,
        description: "Disabled item",
        attributes: %{name: "tier", value: "basic"},
        slots: [
          ~s(<:item value="basic">Basic</:item>),
          ~s|<:item value="premiere" disabled>Premiere room (coming soon)</:item>|,
          ~s(<:item value="archive">Archive access</:item>)
        ]
      },
      %Variation{
        id: :invalid,
        description: "Validation state mirrors field errors through `aria-invalid`",
        attributes: %{name: "role", errors: ["Choose a role"]},
        slots: [
          ~s(<:item value="member">Member</:item>),
          ~s(<:item value="admin">Admin</:item>)
        ]
      },
      %VariationGroup{
        id: :icon_layouts,
        description: "Icon radio-item layout options",
        template: """
        <div class="grid w-full grid-cols-1 gap-6 p-4 text-text xl:grid-cols-2">
          <.psb-variation-group/>
        </div>
        """,
        variations: [
          %Variation{
            id: :horizontal_icon,
            description: "Horizontal icon — compact and keeps the radio affordance clear",
            attributes: %{
              name: "content_type_horizontal",
              value: "movie",
              class: "grid grid-cols-1 gap-3"
            },
            slots: [
              """
              <:item value="movie" class="flex cursor-pointer items-center gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:movie} class="size-5 shrink-0 text-text-muted" />
                <span class="font-medium">Movie</span>
              </:item>
              """,
              """
              <:item value="tv_show" class="flex cursor-pointer items-center gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:tv_show} class="size-5 shrink-0 text-text-muted" />
                <span class="font-medium">TV show</span>
              </:item>
              """,
              """
              <:item value="book" class="flex cursor-pointer items-center gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:book} class="size-5 shrink-0 text-text-muted" />
                <span class="font-medium">Book</span>
              </:item>
              """
            ]
          },
          %Variation{
            id: :stacked_centered,
            description: "Stacked centered — more visual, but taller",
            attributes: %{
              name: "content_type_stacked",
              value: "tv_show",
              class: "grid grid-cols-3 gap-3"
            },
            slots: [
              """
              <:item value="movie" class="flex min-h-32 cursor-pointer flex-col items-center justify-center gap-3 rounded-control border border-border bg-surface-inset p-4 text-center transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:movie} class="size-7 text-text-muted" />
                <span class="font-medium">Movie</span>
              </:item>
              """,
              """
              <:item value="tv_show" class="flex min-h-32 cursor-pointer flex-col items-center justify-center gap-3 rounded-control border border-border bg-surface-inset p-4 text-center transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:tv_show} class="size-7 text-text-muted" />
                <span class="font-medium">TV show</span>
              </:item>
              """,
              """
              <:item value="book" class="flex min-h-32 cursor-pointer flex-col items-center justify-center gap-3 rounded-control border border-border bg-surface-inset p-4 text-center transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:book} class="size-7 text-text-muted" />
                <span class="font-medium">Book</span>
              </:item>
              """
            ]
          },
          %Variation{
            id: :corner_radio_tile,
            description: "Corner radio tile — visual tile with the radio in the corner",
            attributes: %{
              name: "content_type_corner",
              value: "book",
              class: "grid grid-cols-3 gap-3"
            },
            slots: [
              """
              <:item value="movie" class="grid min-h-28 cursor-pointer grid-cols-[auto_1fr] grid-rows-[auto_1fr] gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:movie} class="col-start-2 ml-auto size-7 text-text-muted" />
                <span class="col-span-2 mt-auto font-medium">Movie</span>
              </:item>
              """,
              """
              <:item value="tv_show" class="grid min-h-28 cursor-pointer grid-cols-[auto_1fr] grid-rows-[auto_1fr] gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:tv_show} class="col-start-2 ml-auto size-7 text-text-muted" />
                <span class="col-span-2 mt-auto font-medium">TV show</span>
              </:item>
              """,
              """
              <:item value="book" class="grid min-h-28 cursor-pointer grid-cols-[auto_1fr] grid-rows-[auto_1fr] gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected">
                <.content_type_icon type={:book} class="col-start-2 ml-auto size-7 text-text-muted" />
                <span class="col-span-2 mt-auto font-medium">Book</span>
              </:item>
              """
            ]
          },
          %Variation{
            id: :check_card,
            description:
              "Check-card — clean selected-card pattern, less explicit as a radio group",
            attributes: %{
              name: "content_type_check_card",
              value: "movie",
              class: "grid grid-cols-1 gap-3"
            },
            slots: [
              """
              <:item value="movie" class="group/radio-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected [&>[data-slot=radio-group-item]]:sr-only">
                <.content_type_icon type={:movie} class="size-5 text-text-muted" />
                <span class="font-medium">Movie</span>
                <Lucideicons.check class="size-4 text-primary opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
              </:item>
              """,
              """
              <:item value="tv_show" class="group/radio-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected [&>[data-slot=radio-group-item]]:sr-only">
                <.content_type_icon type={:tv_show} class="size-5 text-text-muted" />
                <span class="font-medium">TV show</span>
                <Lucideicons.check class="size-4 text-primary opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
              </:item>
              """,
              """
              <:item value="book" class="group/radio-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-3 rounded-control border border-border bg-surface-inset p-3 transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected [&>[data-slot=radio-group-item]]:sr-only">
                <.content_type_icon type={:book} class="size-5 text-text-muted" />
                <span class="font-medium">Book</span>
                <Lucideicons.check class="size-4 text-primary opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
              </:item>
              """
            ]
          }
        ]
      }
    ]
  end
end

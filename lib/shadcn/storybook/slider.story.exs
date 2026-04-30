defmodule Shadcn.Storybook.Slider do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Slider

  def function, do: &Slider.slider/1

  def variations do
    [
      %Variation{
        id: :default,
        description: "Single thumb",
        attributes: %{id: "slider-default", name: "default", value: 33}
      },
      %Variation{
        id: :range,
        description: "Range (two thumbs)",
        attributes: %{id: "slider-range", name: "range", value: [25, 75]}
      },
      %Variation{
        id: :multiple,
        description: "Multiple thumbs",
        attributes: %{id: "slider-multi", name: "multi", value: [10, 40, 80]}
      },
      %Variation{
        id: :stepped,
        description: "Stepped (step=10)",
        attributes: %{
          id: "slider-stepped",
          name: "stepped",
          min: 0,
          max: 100,
          step: 10,
          value: 30
        }
      },
      %Variation{
        id: :min_steps_between_thumbs,
        description: "Range with min_steps_between_thumbs=10",
        attributes: %{
          id: "slider-min-steps",
          name: "min-steps",
          value: [30, 70],
          min_steps_between_thumbs: 10
        }
      },
      %Variation{
        id: :disabled,
        attributes: %{id: "slider-disabled", name: "disabled", value: 40, disabled: true}
      },
      %Variation{
        id: :vertical,
        description: "Vertical orientation",
        template: """
        <div class="h-[200px] p-4">
          <.psb-variation/>
        </div>
        """,
        attributes: %{
          id: "slider-vert",
          name: "vert",
          orientation: "vertical",
          value: 30
        }
      },
      %Variation{
        id: :vertical_range,
        description: "Vertical range",
        template: """
        <div class="h-[200px] p-4">
          <.psb-variation/>
        </div>
        """,
        attributes: %{
          id: "slider-vert-range",
          name: "vert-range",
          orientation: "vertical",
          value: [20, 80]
        }
      }
    ]
  end
end

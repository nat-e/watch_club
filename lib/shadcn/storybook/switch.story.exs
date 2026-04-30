defmodule Shadcn.Storybook.Switch do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Switch

  def function, do: &Switch.switch/1

  def variations do
    [
      %Variation{
        id: :unchecked,
        attributes: %{name: "demo"}
      },
      %Variation{
        id: :checked,
        attributes: %{name: "demo", checked: true}
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        template: """
        <div class="flex items-center gap-4">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for s <- ~w(sm default) do
            %Variation{
              id: String.to_atom(s),
              attributes: %{name: "size-#{s}", size: s, checked: true}
            }
          end
      },
      %Variation{
        id: :disabled,
        attributes: %{name: "demo", disabled: true}
      },
      %Variation{
        id: :disabled_checked,
        attributes: %{name: "demo", disabled: true, checked: true}
      }
    ]
  end
end

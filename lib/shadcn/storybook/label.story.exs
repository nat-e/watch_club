defmodule Shadcn.Storybook.Label do
  use PhoenixStorybook.Story, :component

  def function, do: &Shadcn.Components.Label.label/1
  def imports, do: [{Shadcn.Components.Input, [input: 1]}]

  def template do
    """
    <div class="grid w-full max-w-sm gap-2">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{for: "email"},
        slots: ["Email"]
      },
      %Variation{
        id: :with_input,
        description: "Paired with input",
        template: """
        <div class="grid w-full max-w-sm gap-2">
          <.psb-variation/>
          <.input id="email-input" name="email" type="email" placeholder="you@example.com" />
        </div>
        """,
        attributes: %{for: "email-input"},
        slots: ["Email address"]
      }
    ]
  end
end

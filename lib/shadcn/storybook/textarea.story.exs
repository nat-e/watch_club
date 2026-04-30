defmodule Shadcn.Storybook.Textarea do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Textarea

  def function, do: &Textarea.textarea/1

  defp container_template(content) do
    """
    <div class="w-[420px]">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{placeholder: "Type your message here."}
      },
      %Variation{
        id: :with_value,
        description: "With initial value",
        attributes: %{
          value: "The quick brown fox jumps over the lazy dog.",
          placeholder: "Type your message here."
        }
      },
      %Variation{
        id: :disabled,
        attributes: %{
          disabled: true,
          placeholder: "Type your message here.",
          value: "Disabled textarea"
        }
      },
      %Variation{
        id: :invalid,
        description: "Invalid (aria-invalid)",
        attributes: %{
          placeholder: "Type your message here.",
          "aria-invalid": "true",
          value: "Bad input"
        }
      },
      %Variation{
        id: :rows,
        description: "Fixed rows",
        attributes: %{rows: 6, placeholder: "6-row textarea"}
      }
    ]
  end
end

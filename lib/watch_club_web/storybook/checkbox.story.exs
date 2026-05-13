defmodule WatchClubWeb.Storybook.Checkbox do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.UI.Checkbox

  def function, do: &Checkbox.checkbox/1

  defp container_template(content) do
    """
    <div class="grid w-full max-w-sm gap-5 p-4 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default checkbox",
        template: """
        <label class="flex items-center gap-3 text-sm font-medium">
          <.checkbox id="wc-checkbox-default" />
          Add new recommendations to my watchlist
        </label>
        """
      },
      %Variation{
        id: :checked,
        description: "Checked state",
        template: """
        <label class="flex items-center gap-3 text-sm font-medium">
          <.checkbox id="wc-checkbox-checked" checked />
          Share updates with club members
        </label>
        """
      },
      %Variation{
        id: :with_description,
        description: "Label and helper text",
        template: """
        <div class="flex items-start gap-3">
          <.checkbox id="wc-checkbox-description" checked />
          <div class="grid gap-1">
            <label for="wc-checkbox-description" class="text-sm font-medium">
              Enable club notifications
            </label>
            <p class="text-sm text-text-muted">
              Receive updates when members add recommendations or invitations change.
            </p>
          </div>
        </div>
        """
      },
      %Variation{
        id: :invalid,
        description: "Validation state",
        template: """
        <div class="flex items-start gap-3">
          <.checkbox id="wc-checkbox-invalid" errors={["Required"]} />
          <div class="grid gap-1">
            <label for="wc-checkbox-invalid" class="text-sm font-medium">
              Accept the club rules
            </label>
            <p class="text-sm text-danger">This must be accepted before continuing.</p>
          </div>
        </div>
        """
      },
      %Variation{
        id: :disabled,
        description: "Disabled state",
        template: """
        <label class="flex items-center gap-3 text-sm font-medium text-text-disabled">
          <.checkbox id="wc-checkbox-disabled" disabled />
          This option is unavailable
        </label>
        """
      },
      %Variation{
        id: :group,
        description: "Checkbox group",
        template: """
        <fieldset class="grid gap-3">
          <legend class="mb-1 text-sm font-semibold">Content types</legend>
          <label class="flex items-center gap-3 text-sm">
            <.checkbox id="wc-checkbox-movies" name="types[]" value="movie" checked />
            Movies
          </label>
          <label class="flex items-center gap-3 text-sm">
            <.checkbox id="wc-checkbox-shows" name="types[]" value="tv_show" />
            TV shows
          </label>
          <label class="flex items-center gap-3 text-sm">
            <.checkbox id="wc-checkbox-books" name="types[]" value="book" />
            Books
          </label>
        </fieldset>
        """
      }
    ]
  end
end

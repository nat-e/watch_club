defmodule WatchClubWeb.Storybook.Flash do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Flash

  def function, do: &Flash.flash/1

  @template """
  <div class="relative h-44 w-full overflow-hidden rounded-card border border-border bg-surface p-4" style="transform:translateZ(0)">
    <.psb-variation/>
  </div>
  """

  @tall_template """
  <div class="relative h-64 w-full overflow-hidden rounded-card border border-border bg-surface p-4" style="transform:translateZ(0)">
    <.psb-variation/>
  </div>
  """

  def variations do
    [
      %Variation{
        id: :info,
        description: "Single informational toast",
        template: @template,
        attributes: %{
          id: "wc-flash-info",
          flash: %{"info" => "Your changes were synced."},
          duration: 0
        }
      },
      %Variation{
        id: :success,
        description: "Success toast",
        template: @template,
        attributes: %{
          id: "wc-flash-success",
          flash: %{"success" => "Profile updated successfully."},
          duration: 0
        }
      },
      %Variation{
        id: :warning,
        description: "Warning toast",
        template: @template,
        attributes: %{
          id: "wc-flash-warning",
          flash: %{"warning" => "Your session will expire in 5 minutes."},
          duration: 0
        }
      },
      %Variation{
        id: :error,
        description: "Error toast",
        template: @template,
        attributes: %{
          id: "wc-flash-error",
          flash: %{"error" => "Failed to save your changes. Please try again."},
          duration: 0
        }
      },
      %Variation{
        id: :multiple,
        description: "Multiple toasts stack in order",
        template: @tall_template,
        attributes: %{
          id: "wc-flash-multiple",
          flash: %{
            "success" => "Saved.",
            "info" => "Synced 12 items.",
            "warning" => "1 item skipped.",
            "error" => "1 item failed."
          },
          duration: 0
        }
      },
      %Variation{
        id: :top_center,
        description: ~s|position="top-center"|,
        template: @template,
        attributes: %{
          id: "wc-flash-top-center",
          flash: %{"info" => "Pinned to top-center."},
          position: "top-center",
          duration: 0
        }
      },
      %Variation{
        id: :long_message,
        description: "Long messages wrap inside the toast",
        template: @template,
        attributes: %{
          id: "wc-flash-long",
          flash: %{
            "info" =>
              "Your subscription will renew automatically on the 15th. Update billing information now to avoid service interruption."
          },
          duration: 0
        }
      },
      %Variation{
        id: :auto_dismiss,
        description: "Auto-dismiss after 3 seconds",
        template: @template,
        attributes: %{
          id: "wc-flash-auto",
          flash: %{"success" => "I'll fade out in 3s."},
          duration: 3000
        }
      }
    ]
  end
end

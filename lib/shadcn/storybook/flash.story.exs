defmodule Shadcn.Storybook.Flash do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Flash

  def function, do: &Flash.flash/1

  # Wraps each toaster in a fixed-size containing block.
  # `transform: translateZ(0)` makes the wrapper a containing block for
  # `position: fixed` descendants, so each variation's toaster stays inside
  # its own preview tile instead of pinning to the page viewport.
  @template """
  <div class="relative h-44 w-full overflow-hidden rounded-md border bg-muted/20" style="transform:translateZ(0)">
    <.psb-variation/>
  </div>
  """

  @tall_template """
  <div class="relative h-64 w-full overflow-hidden rounded-md border bg-muted/20" style="transform:translateZ(0)">
    <.psb-variation/>
  </div>
  """

  def variations do
    [
      %Variation{
        id: :info,
        description: "Single :info flash — default position (bottom-right)",
        template: @template,
        attributes: %{
          id: "ft-info",
          flash: %{"info" => "Your changes were synced."},
          duration: 0
        }
      },
      %Variation{
        id: :success,
        description: "Single :success flash",
        template: @template,
        attributes: %{
          id: "ft-success",
          flash: %{"success" => "Profile updated successfully."},
          duration: 0
        }
      },
      %Variation{
        id: :warning,
        description: "Single :warning flash",
        template: @template,
        attributes: %{
          id: "ft-warning",
          flash: %{"warning" => "Your session will expire in 5 minutes."},
          duration: 0
        }
      },
      %Variation{
        id: :error,
        description: "Single :error flash",
        template: @template,
        attributes: %{
          id: "ft-error",
          flash: %{"error" => "Failed to save your changes. Please try again."},
          duration: 0
        }
      },
      %Variation{
        id: :multiple,
        description: "Two kinds at once — info and error stacked",
        template: @tall_template,
        attributes: %{
          id: "ft-multi",
          flash: %{
            "info" => "Connected to the server.",
            "error" => "Could not load your profile picture."
          },
          duration: 0
        }
      },
      %Variation{
        id: :all_kinds,
        description: "All four kinds simultaneously, in default render order",
        template: @tall_template,
        attributes: %{
          id: "ft-all",
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
        id: :top_left,
        description: ~s|position="top-left"|,
        template: @template,
        attributes: %{
          id: "ft-tl",
          flash: %{"info" => "Pinned to top-left."},
          position: "top-left",
          duration: 0
        }
      },
      %Variation{
        id: :top_center,
        description: ~s|position="top-center"|,
        template: @template,
        attributes: %{
          id: "ft-tc",
          flash: %{"info" => "Pinned to top-center."},
          position: "top-center",
          duration: 0
        }
      },
      %Variation{
        id: :top_right,
        description: ~s|position="top-right"|,
        template: @template,
        attributes: %{
          id: "ft-tr",
          flash: %{"info" => "Pinned to top-right."},
          position: "top-right",
          duration: 0
        }
      },
      %Variation{
        id: :bottom_left,
        description: ~s|position="bottom-left"|,
        template: @template,
        attributes: %{
          id: "ft-bl",
          flash: %{"info" => "Pinned to bottom-left."},
          position: "bottom-left",
          duration: 0
        }
      },
      %Variation{
        id: :bottom_center,
        description: ~s|position="bottom-center"|,
        template: @template,
        attributes: %{
          id: "ft-bc",
          flash: %{"info" => "Pinned to bottom-center."},
          position: "bottom-center",
          duration: 0
        }
      },
      %Variation{
        id: :long_message,
        description: "Long message — wraps inside the toast",
        template: @template,
        attributes: %{
          id: "ft-long",
          flash: %{
            "info" =>
              "Your subscription will renew automatically on the 15th. Update your billing information now to avoid any service interruption."
          },
          duration: 0
        }
      },
      %Variation{
        id: :auto_dismiss,
        description: "Auto-dismiss after 3 seconds (refresh the story to retrigger)",
        template: @template,
        attributes: %{
          id: "ft-auto",
          flash: %{"success" => "I'll fade out in 3s."},
          duration: 3000
        }
      },
      %Variation{
        id: :custom_kinds,
        description: ~s|kinds={[:error]} — only render :error|,
        template: @template,
        attributes: %{
          id: "ft-only-error",
          flash: %{
            "info" => "This info will not show.",
            "error" => "Only this error renders."
          },
          kinds: [:error],
          duration: 0
        }
      }
    ]
  end
end

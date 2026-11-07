defmodule WatchClubWeb.Storybook.PrototypeFrame do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Prototypes.Frame

  def function, do: &Frame.prototype_frame/1

  def variations do
    [
      %Variation{
        id: :experiment,
        description: "The goal and level of an experiment above its content.",
        attributes: %{
          id: "prototype-frame-experiment",
          title: "Browse layouts",
          description: "Find a movie to watch from the Library.",
          level: "reshape"
        },
        slots: [~s(<p class="text-text-muted">The prototype's screen goes here.</p>)]
      },
      %Variation{
        id: :developer_tools,
        attributes: %{
          id: "prototype-frame-tools",
          title: "Prototypes",
          description: "Local experiments in this worktree.",
          back: "/dev",
          back_label: "Development"
        },
        slots: [~s(<p class="text-text-muted">Experiments and their pages.</p>)]
      }
    ]
  end
end

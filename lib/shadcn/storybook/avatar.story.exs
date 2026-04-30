defmodule Shadcn.Storybook.Avatar do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Avatar

  def function, do: &Avatar.avatar/1

  def imports,
    do: [
      {Shadcn.Components.Avatar, [avatar_group: 1]},
      {Lucideicons, [check: 1, plus: 1, user: 1]}
    ]

  @meta Avatar.__components__().avatar
  @sizes Enum.find(@meta.attrs, &(&1.name == :size)).opts[:values]

  @sample_src "https://github.com/shadcn.png"
  @broken_src "https://example.com/does-not-exist.png"

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{id: "av-default"},
        slots: [
          ~s(<:image src="#{@sample_src}" alt="shadcn" />),
          "<:fallback>SC</:fallback>"
        ]
      },
      %Variation{
        id: :fallback_only,
        description: "Fallback only (no image slot)",
        slots: ["<:fallback>JD</:fallback>"]
      },
      %Variation{
        id: :error,
        description: "Image error → fallback wins",
        attributes: %{id: "av-error"},
        slots: [
          ~s(<:image src="#{@broken_src}" alt="broken" />),
          "<:fallback>JD</:fallback>"
        ]
      },
      %Variation{
        id: :delayed_fallback,
        description: "Fallback with delay_ms (avoids flash on fast loads)",
        attributes: %{id: "av-delayed"},
        slots: [
          ~s(<:image src="#{@sample_src}" alt="shadcn" />),
          "<:fallback delay_ms={600}>SC</:fallback>"
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        template: """
        <div class="flex items-center gap-3">
          <.psb-variation/>
        </div>
        """,
        variations:
          for s <- @sizes do
            %Variation{
              id: String.to_atom(s),
              attributes: %{id: "av-size-#{s}", size: s},
              slots: [~s(<:image src="#{@sample_src}" alt="shadcn" />)]
            }
          end
      },
      %VariationGroup{
        id: :sizes_fallback,
        description: "Sizes (fallback)",
        template: """
        <div class="flex items-center gap-3">
          <.psb-variation/>
        </div>
        """,
        variations:
          for s <- @sizes do
            %Variation{
              id: String.to_atom(s),
              attributes: %{size: s},
              slots: ["<:fallback>JD</:fallback>"]
            }
          end
      },
      %Variation{
        id: :with_badge,
        description: "With badge",
        attributes: %{id: "av-badge", size: "lg"},
        slots: [
          ~s(<:image src="#{@sample_src}" alt="shadcn" />),
          "<:badge><Lucideicons.check /></:badge>"
        ]
      },
      %VariationGroup{
        id: :badge_sizes,
        description: "Badge across sizes",
        template: """
        <div class="flex items-center gap-3">
          <.psb-variation/>
        </div>
        """,
        variations:
          for s <- @sizes do
            %Variation{
              id: String.to_atom(s),
              attributes: %{id: "av-badge-#{s}", size: s},
              slots: [
                ~s(<:image src="#{@sample_src}" alt="shadcn" />),
                "<:badge><Lucideicons.check /></:badge>"
              ]
            }
          end
      },
      %Variation{
        id: :group,
        description: "Avatar group",
        template: """
        <.avatar_group>
          <.avatar id="av-grp-1"><:image src="https://github.com/shadcn.png" alt="A" /></.avatar>
          <.avatar><:fallback>BS</:fallback></.avatar>
          <.avatar><:fallback>CT</:fallback></.avatar>
          <:count>+5</:count>
        </.avatar_group>
        """
      },
      %Variation{
        id: :group_sm,
        description: "Avatar group (sm)",
        template: """
        <.avatar_group>
          <.avatar id="av-grp-sm-1" size="sm"><:image src="https://github.com/shadcn.png" alt="A" /></.avatar>
          <.avatar size="sm"><:fallback>BS</:fallback></.avatar>
          <.avatar size="sm"><:fallback>CT</:fallback></.avatar>
          <:count>+5</:count>
        </.avatar_group>
        """
      },
      %Variation{
        id: :group_lg,
        description: "Avatar group (lg)",
        template: """
        <.avatar_group>
          <.avatar id="av-grp-lg-1" size="lg"><:image src="https://github.com/shadcn.png" alt="A" /></.avatar>
          <.avatar size="lg"><:fallback>BS</:fallback></.avatar>
          <.avatar size="lg"><:fallback>CT</:fallback></.avatar>
          <:count>+5</:count>
        </.avatar_group>
        """
      }
    ]
  end
end

defmodule Storybook.UI.Collapsible do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Collapsible

  def function, do: &Collapsible.collapsible/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.Card, [card: 1]},
      {Lucideicons, [chevron_down: 1, chevron_right: 1, file: 1, folder: 1]}
    ]

  @file_tree [
    %{
      name: "components",
      open: true,
      items: [
        %{
          name: "ui",
          items: [
            %{name: "button.tsx"},
            %{name: "card.tsx"},
            %{name: "dialog.tsx"},
            %{name: "input.tsx"},
            %{name: "select.tsx"},
            %{name: "table.tsx"}
          ]
        },
        %{name: "login-form.tsx"},
        %{name: "register-form.tsx"}
      ]
    },
    %{
      name: "lib",
      items: [%{name: "utils.ts"}, %{name: "cn.ts"}, %{name: "api.ts"}]
    },
    %{
      name: "hooks",
      items: [
        %{name: "use-media-query.ts"},
        %{name: "use-debounce.ts"},
        %{name: "use-local-storage.ts"}
      ]
    },
    %{name: "types", items: [%{name: "index.d.ts"}, %{name: "api.d.ts"}]},
    %{
      name: "public",
      items: [%{name: "favicon.ico"}, %{name: "logo.svg"}, %{name: "images"}]
    },
    %{name: "app.tsx"},
    %{name: "layout.tsx"},
    %{name: "globals.css"},
    %{name: "package.json"},
    %{name: "tsconfig.json"},
    %{name: "README.md"},
    %{name: ".gitignore"}
  ]

  @trigger_class "flex items-center gap-2 rounded-md px-2 py-1 text-sm font-medium hover:bg-accent hover:text-accent-foreground"
  @file_class "flex items-center gap-2 rounded-md px-2 py-1 text-sm text-foreground hover:bg-accent hover:text-accent-foreground"
  @chevron_class "size-4 shrink-0 transition-transform [details[open]>summary>&]:rotate-90"

  defp render_item(%{items: items} = item) do
    open_attr = if item[:open], do: " open", else: ""

    """
    <.collapsible#{open_attr}>
      <:trigger class="#{@trigger_class}">
        <Lucideicons.chevron_right class="#{@chevron_class}" />
        <Lucideicons.folder class="size-4 shrink-0" />
        #{item.name}
      </:trigger>
      <div class="ml-5 mt-1 flex flex-col gap-1">
        #{Enum.map_join(items, "\n", &render_item/1)}
      </div>
    </.collapsible>
    """
  end

  defp render_item(%{name: name}) do
    """
    <span class="#{@file_class}">
      <Lucideicons.file class="size-4 shrink-0" />
      #{name}
    </span>
    """
  end

  defp file_tree_template do
    """
    <.card class="mx-auto w-full max-w-[16rem]" size="sm">
      <:title>Explorer</:title>
      <div class="flex flex-col gap-1">
        #{Enum.map_join(@file_tree, "\n", &render_item/1)}
      </div>
    </.card>
    """
  end

  def variations do
    [
      %Variation{
        id: :basic,
        description: "Basic",
        template: """
        <.card class="mx-auto w-full max-w-sm">
          <.collapsible class="rounded-md [&[open]]:bg-muted">
            <:trigger class="group/trigger flex w-full items-center rounded-md px-2.5 py-2 text-sm font-medium hover:bg-muted">
              Product details
              <Lucideicons.chevron_down class="ml-auto size-4 transition-transform [details[open]>summary>&]:rotate-180" />
            </:trigger>
            <div class="flex flex-col items-start gap-2 p-2.5 pt-0 text-sm">
              <div>
                This panel can be expanded or collapsed to reveal additional content.
              </div>
              <.button size="xs">Learn More</.button>
            </div>
          </.collapsible>
        </.card>
        """
      },
      %Variation{
        id: :file_tree,
        description: "File tree",
        template: file_tree_template()
      }
    ]
  end
end

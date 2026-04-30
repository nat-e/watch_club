defmodule Shadcn.Storybook.Item do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Item

  def function, do: &Item.item/1

  def imports,
    do: [
      {Shadcn.Components.Item, [item_group: 1]},
      {Shadcn.Components.Avatar, [avatar: 1]},
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.DropdownMenu,
       [dropdown_menu: 1, dropdown_menu_group: 1, dropdown_menu_item: 1]},
      {Lucideicons,
       [
         badge_check: 1,
         chevron_down: 1,
         chevron_right: 1,
         external_link: 1,
         inbox: 1,
         plus: 1,
         shield_alert: 1
       ]}
    ]

  defp container_template(content) do
    """
    <div class="w-full max-w-xl p-4">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :demo,
        description: "Basic outlined item with action",
        attributes: %{variant: "outline"},
        slots: [
          ~s|<:title>Basic Item</:title>|,
          ~s|<:description>A simple item with title and description.</:description>|,
          ~s|<:actions><.button variant="outline" size="sm">Action</.button></:actions>|
        ]
      },
      %Variation{
        id: :variant,
        description: "Three variants: default / outline / muted",
        template: """
        <div class="flex w-full max-w-md flex-col gap-6">
          <.item>
            <:media variant="icon"><Lucideicons.inbox /></:media>
            <:title>Default Variant</:title>
            <:description>Transparent background with no border.</:description>
          </.item>
          <.item variant="outline">
            <:media variant="icon"><Lucideicons.inbox /></:media>
            <:title>Outline Variant</:title>
            <:description>Outlined style with a visible border.</:description>
          </.item>
          <.item variant="muted">
            <:media variant="icon"><Lucideicons.inbox /></:media>
            <:title>Muted Variant</:title>
            <:description>Muted background for secondary content.</:description>
          </.item>
        </div>
        """
      },
      %Variation{
        id: :size,
        description: "Three sizes: xs / sm / default (ascending)",
        template: """
        <div class="flex w-full max-w-md flex-col gap-6">
          <.item variant="outline" size="xs">
            <:media variant="icon"><Lucideicons.inbox /></:media>
            <:title>Extra Small Size</:title>
            <:description>The most compact size available.</:description>
          </.item>
          <.item variant="outline" size="sm">
            <:media variant="icon"><Lucideicons.inbox /></:media>
            <:title>Small Size</:title>
            <:description>A compact size for dense layouts.</:description>
          </.item>
          <.item variant="outline">
            <:media variant="icon"><Lucideicons.inbox /></:media>
            <:title>Default Size</:title>
            <:description>The standard size for most use cases.</:description>
          </.item>
        </div>
        """
      },
      %Variation{
        id: :icon,
        description: "Item with icon media and action",
        template: """
        <.item variant="outline" class="max-w-lg">
          <:media variant="icon"><Lucideicons.shield_alert /></:media>
          <:title>Security Alert</:title>
          <:description>New login detected from unknown device.</:description>
          <:actions>
            <.button size="sm" variant="outline">Review</.button>
          </:actions>
        </.item>
        """
      },
      %Variation{
        id: :avatar,
        description: "Item with avatar media (single + group)",
        template: """
        <div class="flex w-full max-w-lg flex-col gap-6">
          <.item variant="outline">
            <:media>
              <.avatar class="size-10">
                <:image src="https://github.com/evilrabbit.png" alt="@evilrabbit" />
                <:fallback>ER</:fallback>
              </.avatar>
            </:media>
            <:title>Evil Rabbit</:title>
            <:description>Last seen 5 months ago</:description>
            <:actions>
              <.button size="icon-sm" variant="outline" class="rounded-full" aria-label="Invite">
                <Lucideicons.plus />
              </.button>
            </:actions>
          </.item>
          <.item variant="outline">
            <:media>
              <div class="flex -space-x-2 *:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background *:data-[slot=avatar]:grayscale">
                <.avatar>
                  <:image src="https://github.com/shadcn.png" alt="@shadcn" />
                  <:fallback>CN</:fallback>
                </.avatar>
                <.avatar>
                  <:image src="https://github.com/maxleiter.png" alt="@maxleiter" />
                  <:fallback>LR</:fallback>
                </.avatar>
                <.avatar>
                  <:image src="https://github.com/evilrabbit.png" alt="@evilrabbit" />
                  <:fallback>ER</:fallback>
                </.avatar>
              </div>
            </:media>
            <:title>No Team Members</:title>
            <:description>Invite your team to collaborate on this project.</:description>
            <:actions>
              <.button size="sm" variant="outline">Invite</.button>
            </:actions>
          </.item>
        </div>
        """
      },
      %Variation{
        id: :image,
        description: "Item group with image media",
        template: """
        <.item_group class="w-full max-w-md gap-4">
          <.item variant="outline" href="#">
            <:media variant="image">
              <img src="https://avatar.vercel.sh/Midnight%20City%20Lights" alt="Midnight City Lights" class="grayscale" />
            </:media>
            <:title class="line-clamp-1">
              Midnight City Lights - <span class="text-muted-foreground">Electric Nights</span>
            </:title>
            <:description>Neon Dreams</:description>
            <:actions>
              <span class="text-sm text-muted-foreground">3:45</span>
            </:actions>
          </.item>
          <.item variant="outline" href="#">
            <:media variant="image">
              <img src="https://avatar.vercel.sh/Coffee%20Shop%20Conversations" alt="Coffee Shop Conversations" class="grayscale" />
            </:media>
            <:title class="line-clamp-1">
              Coffee Shop Conversations - <span class="text-muted-foreground">Urban Stories</span>
            </:title>
            <:description>The Morning Brew</:description>
            <:actions>
              <span class="text-sm text-muted-foreground">4:05</span>
            </:actions>
          </.item>
          <.item variant="outline" href="#">
            <:media variant="image">
              <img src="https://avatar.vercel.sh/Digital%20Rain" alt="Digital Rain" class="grayscale" />
            </:media>
            <:title class="line-clamp-1">
              Digital Rain - <span class="text-muted-foreground">Binary Beats</span>
            </:title>
            <:description>Cyber Symphony</:description>
            <:actions>
              <span class="text-sm text-muted-foreground">3:30</span>
            </:actions>
          </.item>
        </.item_group>
        """
      },
      %Variation{
        id: :group,
        description: "People list with avatars and add buttons",
        template: """
        <.item_group class="max-w-sm">
          <.item variant="outline">
            <:media>
              <.avatar>
                <:image src="https://github.com/shadcn.png" alt="@shadcn" class="grayscale" />
                <:fallback>S</:fallback>
              </.avatar>
            </:media>
            <:title>shadcn</:title>
            <:description>shadcn@vercel.com</:description>
            <:actions>
              <.button variant="ghost" size="icon" class="rounded-full">
                <Lucideicons.plus />
              </.button>
            </:actions>
          </.item>
          <.item variant="outline">
            <:media>
              <.avatar>
                <:image src="https://github.com/maxleiter.png" alt="@maxleiter" class="grayscale" />
                <:fallback>M</:fallback>
              </.avatar>
            </:media>
            <:title>maxleiter</:title>
            <:description>maxleiter@vercel.com</:description>
            <:actions>
              <.button variant="ghost" size="icon" class="rounded-full">
                <Lucideicons.plus />
              </.button>
            </:actions>
          </.item>
          <.item variant="outline">
            <:media>
              <.avatar>
                <:image src="https://github.com/evilrabbit.png" alt="@evilrabbit" class="grayscale" />
                <:fallback>E</:fallback>
              </.avatar>
            </:media>
            <:title>evilrabbit</:title>
            <:description>evilrabbit@vercel.com</:description>
            <:actions>
              <.button variant="ghost" size="icon" class="rounded-full">
                <Lucideicons.plus />
              </.button>
            </:actions>
          </.item>
        </.item_group>
        """
      },
      %Variation{
        id: :header,
        description: "Items with header (image on top, content below)",
        template: """
        <.item_group class="grid w-full grid-cols-2 gap-4">
          <.item variant="outline">
            <:header>
              <img src="https://images.unsplash.com/photo-1650804068570-7fb2e3dbf888?q=80&w=320&auto=format&fit=crop" alt="v0-1.5-sm" class="aspect-square w-full rounded-sm object-cover" />
            </:header>
            <:title>v0-1.5-sm</:title>
            <:description>Everyday tasks and UI generation.</:description>
          </.item>
          <.item variant="outline">
            <:header>
              <img src="https://images.unsplash.com/photo-1610280777472-54133d004c8c?q=80&w=320&auto=format&fit=crop" alt="v0-1.5-lg" class="aspect-square w-full rounded-sm object-cover" />
            </:header>
            <:title>v0-1.5-lg</:title>
            <:description>Advanced thinking or reasoning.</:description>
          </.item>
        </.item_group>
        """
      },
      %Variation{
        id: :link,
        description: "Items rendered as anchor tags",
        template: """
        <div class="flex w-full max-w-md flex-col gap-4">
          <.item href="#">
            <:title>Visit our documentation</:title>
            <:description>Learn how to get started with our components.</:description>
            <:actions>
              <Lucideicons.chevron_right class="size-4" />
            </:actions>
          </.item>
          <.item variant="outline" href="#" target="_blank" rel="noopener noreferrer">
            <:title>External resource</:title>
            <:description>Opens in a new tab with security attributes.</:description>
            <:actions>
              <Lucideicons.external_link class="size-4" />
            </:actions>
          </.item>
        </div>
        """
      },
      %Variation{
        id: :verified_link,
        description: "Inline confirmation as a link with media + action",
        template: """
        <.item variant="outline" size="sm" href="#" class="w-full max-w-md">
          <:media>
            <Lucideicons.badge_check class="size-5" />
          </:media>
          <:title>Your profile has been verified.</:title>
          <:actions>
            <Lucideicons.chevron_right class="size-4" />
          </:actions>
        </.item>
        """
      },
      %Variation{
        id: :dropdown,
        description: "Items used inside a dropdown menu",
        template: """
        <.dropdown_menu id="item-dropdown" align="end">
          <:trigger>
            <.button variant="outline">
              Select <Lucideicons.chevron_down />
            </.button>
          </:trigger>
          <.dropdown_menu_group>
            <.dropdown_menu_item>
              <.item size="xs" class="w-full p-2">
                <:media>
                  <.avatar class="size-6">
                    <:image src="https://github.com/shadcn.png" alt="@shadcn" class="grayscale" />
                    <:fallback>S</:fallback>
                  </.avatar>
                </:media>
                <:title>shadcn</:title>
                <:description class="leading-none">shadcn@vercel.com</:description>
              </.item>
            </.dropdown_menu_item>
            <.dropdown_menu_item>
              <.item size="xs" class="w-full p-2">
                <:media>
                  <.avatar class="size-6">
                    <:image src="https://github.com/maxleiter.png" alt="@maxleiter" class="grayscale" />
                    <:fallback>M</:fallback>
                  </.avatar>
                </:media>
                <:title>maxleiter</:title>
                <:description class="leading-none">maxleiter@vercel.com</:description>
              </.item>
            </.dropdown_menu_item>
            <.dropdown_menu_item>
              <.item size="xs" class="w-full p-2">
                <:media>
                  <.avatar class="size-6">
                    <:image src="https://github.com/evilrabbit.png" alt="@evilrabbit" class="grayscale" />
                    <:fallback>E</:fallback>
                  </.avatar>
                </:media>
                <:title>evilrabbit</:title>
                <:description class="leading-none">evilrabbit@vercel.com</:description>
              </.item>
            </.dropdown_menu_item>
          </.dropdown_menu_group>
        </.dropdown_menu>
        """
      }
    ]
  end
end

defmodule WatchClubWeb.Storybook.Table do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Table

  def function, do: &Table.table/1

  def imports,
    do: [
      {WatchClubWeb.Components.UI.Table,
       [
         table_body: 1,
         table_caption: 1,
         table_cell: 1,
         table_footer: 1,
         table_head: 1,
         table_header: 1,
         table_row: 1
       ]},
      {WatchClubWeb.Components.UI.Avatar, [avatar: 1]},
      {WatchClubWeb.Components.UI.Badge, [badge: 1]},
      {WatchClubWeb.Components.UI.Button, [button: 1]},
      {WatchClubWeb.Components.UI.DropdownMenu, [dropdown_menu: 1, dropdown_menu_item: 1]},
      {Lucideicons, [ellipsis_vertical: 1, trash_2: 1, user: 1]}
    ]

  defp container_template(content) do
    """
    <div class="w-full max-w-4xl p-4 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default table with caption, selected row, and footer",
        template: """
        <.table>
          <.table_caption>A list of recent invoices.</.table_caption>
          <.table_header>
            <.table_row>
              <.table_head class="w-[100px]">Invoice</.table_head>
              <.table_head>Status</.table_head>
              <.table_head>Method</.table_head>
              <.table_head class="text-right">Amount</.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row>
              <.table_cell class="font-semibold">INV001</.table_cell>
              <.table_cell><.badge>Paid</.badge></.table_cell>
              <.table_cell>Credit card</.table_cell>
              <.table_cell class="text-right">$250.00</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell class="font-semibold">INV002</.table_cell>
              <.table_cell><.badge variant="secondary">Pending</.badge></.table_cell>
              <.table_cell>PayPal</.table_cell>
              <.table_cell class="text-right">$150.00</.table_cell>
            </.table_row>
            <.table_row selected>
              <.table_cell class="font-semibold">INV003</.table_cell>
              <.table_cell><.badge variant="danger">Failed</.badge></.table_cell>
              <.table_cell>Bank transfer</.table_cell>
              <.table_cell class="text-right">$350.00</.table_cell>
            </.table_row>
          </.table_body>
          <.table_footer>
            <.table_row>
              <.table_cell colspan="3">Total</.table_cell>
              <.table_cell class="text-right">$750.00</.table_cell>
            </.table_row>
          </.table_footer>
        </.table>
        """
      },
      %Variation{
        id: :members,
        description: "Member management table composition",
        template: """
        <.table>
          <.table_header>
            <.table_row>
              <.table_head>User</.table_head>
              <.table_head>Role</.table_head>
              <.table_head>Member since</.table_head>
              <.table_head>Invited by</.table_head>
              <.table_head class="text-right"></.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row>
              <.table_cell>
                <div class="flex items-center justify-center gap-2 font-semibold">
                  <.avatar id="user-ada" name="Ada Lovelace" />
                  Ada Lovelace
                </div>
              </.table_cell>
              <.table_cell><.badge>Admin</.badge></.table_cell>
              <.table_cell>2 days ago</.table_cell>
              <.table_cell>
                <div class="flex items-center justify-center gap-2 font-semibold">
                  <.avatar id="user-grace" name="Grace Hopper" />
                  Grace Hopper
                </div>
              </.table_cell>
              <.table_cell class="text-right">
                <.dropdown_menu id="table-story-actions">
                  <:trigger>
                    <.button id="table-story-member-actions-trigger" size="icon" variant="ghost" aria-label="Member actions">
                      <Lucideicons.ellipsis_vertical />
                    </.button>
                  </:trigger>
                  <.dropdown_menu_item id="table-story-view-profile-item"><Lucideicons.user />View profile</.dropdown_menu_item>
                  <.dropdown_menu_item id="table-story-remove-member-item" variant="destructive"><Lucideicons.trash_2 />Remove member</.dropdown_menu_item>
                </.dropdown_menu>
              </.table_cell>
            </.table_row>
            <.table_row class="text-text-muted">
              <.table_cell>
                <div class="font-semibold italic">Invited guest</div>
              </.table_cell>
              <.table_cell><.badge variant="secondary">Pending</.badge></.table_cell>
              <.table_cell></.table_cell>
              <.table_cell>
                <div class="flex items-center justify-center gap-2 font-semibold">
                  <.avatar id="user-ada" name="Ada Lovelace" />
                  Ada Lovelace
                </div>
              </.table_cell>
              <.table_cell class="text-right"></.table_cell>
            </.table_row>
          </.table_body>
        </.table>
        """
      }
    ]
  end
end

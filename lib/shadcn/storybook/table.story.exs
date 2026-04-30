defmodule Shadcn.Storybook.Table do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Table

  def function, do: &Table.table/1

  def imports,
    do: [
      {Shadcn.Components.Table,
       [
         table_body: 1,
         table_caption: 1,
         table_cell: 1,
         table_footer: 1,
         table_head: 1,
         table_header: 1,
         table_row: 1
       ]},
      {Shadcn.Components.Badge, [badge: 1]}
    ]

  defp container_template(content) do
    """
    <div class="w-[640px]">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        template: """
        <.table>
          <.table_caption>A list of your recent invoices.</.table_caption>
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
              <.table_cell class="font-medium">INV001</.table_cell>
              <.table_cell><.badge>Paid</.badge></.table_cell>
              <.table_cell>Credit Card</.table_cell>
              <.table_cell class="text-right">$250.00</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell class="font-medium">INV002</.table_cell>
              <.table_cell><.badge variant="secondary">Pending</.badge></.table_cell>
              <.table_cell>PayPal</.table_cell>
              <.table_cell class="text-right">$150.00</.table_cell>
            </.table_row>
            <.table_row selected>
              <.table_cell class="font-medium">INV003</.table_cell>
              <.table_cell><.badge variant="destructive">Failed</.badge></.table_cell>
              <.table_cell>Bank Transfer</.table_cell>
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
      }
    ]
  end
end

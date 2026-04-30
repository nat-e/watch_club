defmodule Shadcn.Storybook.Checkbox do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Checkbox

  def function, do: &Checkbox.checkbox/1

  def imports,
    do: [
      {Shadcn.Components.Field,
       [
         field: 1,
         field_content: 1,
         field_description: 1,
         field_group: 1,
         field_label: 1,
         field_title: 1
       ]},
      {Shadcn.Components.Table,
       [
         table: 1,
         table_body: 1,
         table_cell: 1,
         table_head: 1,
         table_header: 1,
         table_row: 1
       ]}
    ]

  def variations do
    [
      %Variation{
        id: :basic,
        description: "Basic",
        template: """
        <.field orientation="horizontal">
          <.checkbox id="terms" />
          <.field_label for="terms">Accept terms and conditions</.field_label>
        </.field>
        """
      },
      %Variation{
        id: :with_description,
        description: "With description",
        template: """
        <.field orientation="horizontal">
          <.checkbox id="terms-2" checked />
          <.field_content>
            <.field_label for="terms-2">Accept terms and conditions</.field_label>
            <.field_description>
              By clicking this checkbox, you agree to the terms and conditions.
            </.field_description>
          </.field_content>
        </.field>
        """
      },
      %Variation{
        id: :invalid,
        description: "Invalid",
        template: """
        <.field orientation="horizontal" invalid>
          <.checkbox id="terms-3" errors={["invalid"]} />
          <.field_label for="terms-3">Accept terms and conditions</.field_label>
        </.field>
        """
      },
      %Variation{
        id: :disabled,
        description: "Disabled",
        template: """
        <.field orientation="horizontal">
          <.checkbox id="toggle" disabled />
          <.field_label for="toggle">Enable notifications</.field_label>
        </.field>
        """
      },
      %Variation{
        id: :with_title,
        description: "With title",
        template: """
        <.field_group>
          <.field_label for="toggle-2">
            <.field orientation="horizontal">
              <.checkbox id="toggle-2" checked />
              <.field_content>
                <.field_title>Enable notifications</.field_title>
                <.field_description>
                  You can enable or disable notifications at any time.
                </.field_description>
              </.field_content>
            </.field>
          </.field_label>
          <.field_label for="toggle-4">
            <.field orientation="horizontal" disabled>
              <.checkbox id="toggle-4" disabled />
              <.field_content>
                <.field_title>Enable notifications</.field_title>
                <.field_description>
                  You can enable or disable notifications at any time.
                </.field_description>
              </.field_content>
            </.field>
          </.field_label>
        </.field_group>
        """
      },
      %Variation{
        id: :in_table,
        description: "In table",
        template: """
        <.table>
          <.table_header>
            <.table_row>
              <.table_head class="w-8">
                <.checkbox id="select-all" />
              </.table_head>
              <.table_head>Name</.table_head>
              <.table_head>Email</.table_head>
              <.table_head>Role</.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row selected>
              <.table_cell><.checkbox id="row-1" checked /></.table_cell>
              <.table_cell class="font-medium">Sarah Chen</.table_cell>
              <.table_cell>sarah.chen@example.com</.table_cell>
              <.table_cell>Admin</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell><.checkbox id="row-2" /></.table_cell>
              <.table_cell class="font-medium">Marcus Rodriguez</.table_cell>
              <.table_cell>marcus.rodriguez@example.com</.table_cell>
              <.table_cell>User</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell><.checkbox id="row-3" /></.table_cell>
              <.table_cell class="font-medium">Priya Patel</.table_cell>
              <.table_cell>priya.patel@example.com</.table_cell>
              <.table_cell>User</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell><.checkbox id="row-4" /></.table_cell>
              <.table_cell class="font-medium">David Kim</.table_cell>
              <.table_cell>david.kim@example.com</.table_cell>
              <.table_cell>Editor</.table_cell>
            </.table_row>
          </.table_body>
        </.table>
        """
      },
      %Variation{
        id: :group,
        description: "Group",
        template: """
        <.field>
          <.field_label>Show these items on the desktop:</.field_label>
          <.field orientation="horizontal">
            <.checkbox id="hard-disks" />
            <.field_label for="hard-disks" class="font-normal">Hard disks</.field_label>
          </.field>
          <.field orientation="horizontal">
            <.checkbox id="external-disks" />
            <.field_label for="external-disks" class="font-normal">External disks</.field_label>
          </.field>
          <.field orientation="horizontal">
            <.checkbox id="cds-dvds" />
            <.field_label for="cds-dvds" class="font-normal">CDs, DVDs, and iPods</.field_label>
          </.field>
          <.field orientation="horizontal">
            <.checkbox id="connected-servers" />
            <.field_label for="connected-servers" class="font-normal">Connected servers</.field_label>
          </.field>
        </.field>
        """
      }
    ]
  end
end

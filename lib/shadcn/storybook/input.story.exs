defmodule Shadcn.Storybook.Input do
  use PhoenixStorybook.Story, :component

  def function, do: &Shadcn.Components.Input.input/1

  def imports,
    do: [
      {Shadcn.Components.Badge, [badge: 1]},
      {WatchClubWeb.UI.Button, [button: 1]},
      {Shadcn.Components.ButtonGroup, [button_group: 1]},
      {Shadcn.Components.Field,
       [
         field: 1,
         field_description: 1,
         field_group: 1,
         field_label: 1
       ]},
      {Shadcn.Components.Select, [select: 1, select_item: 1]}
    ]

  defp container_template(content) do
    """
    <div class="w-full max-w-md p-4">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :basic,
        description: "Standalone input",
        template: ~s|<.input placeholder="Enter text" />|
      },
      %Variation{
        id: :field,
        description: "Input wrapped in a field with label and description",
        template: """
        <.field>
          <.field_label for="input-field-username">Username</.field_label>
          <.input id="input-field-username" type="text" placeholder="Enter your username" />
          <.field_description>Choose a unique username for your account.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :disabled,
        description: "Disabled field",
        template: """
        <.field data-disabled>
          <.field_label for="input-disabled">Email</.field_label>
          <.input id="input-disabled" type="email" placeholder="Email" disabled />
          <.field_description>This field is currently disabled.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :file,
        description: "File input",
        template: """
        <.field>
          <.field_label for="picture">Picture</.field_label>
          <.input id="picture" type="file" />
          <.field_description>Select a picture to upload.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :required,
        description: "Required field marker",
        template: """
        <.field>
          <.field_label for="input-required">
            Required Field <span class="text-destructive">*</span>
          </.field_label>
          <.input id="input-required" placeholder="This field is required" required />
          <.field_description>This field must be filled out.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :invalid,
        description: "Field with validation error styling",
        template: """
        <.field data-invalid>
          <.field_label for="input-invalid">Invalid Input</.field_label>
          <.input id="input-invalid" placeholder="Error" aria-invalid="true" />
          <.field_description>This field contains validation errors.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :badge,
        description: "Label with inline badge",
        template: """
        <.field>
          <.field_label for="input-badge">
            Webhook URL <.badge variant="secondary" class="ml-auto">Beta</.badge>
          </.field_label>
          <.input id="input-badge" type="url" placeholder="https://api.example.com/webhook" />
        </.field>
        """
      },
      %Variation{
        id: :inline,
        description: "Horizontal field — inline search",
        template: """
        <.field orientation="horizontal">
          <.input type="search" placeholder="Search..." />
          <.button>Search</.button>
        </.field>
        """
      },
      %Variation{
        id: :button_group,
        description: "Input attached to a trailing button",
        template: """
        <.field>
          <.field_label for="input-button-group">Search</.field_label>
          <.button_group>
            <.input id="input-button-group" placeholder="Type to search..." />
            <.button variant="outline">Search</.button>
          </.button_group>
        </.field>
        """
      },
      %Variation{
        id: :grid,
        description: "Two-column grid of fields",
        template: """
        <.field_group class="grid max-w-sm grid-cols-2">
          <.field>
            <.field_label for="first-name">First Name</.field_label>
            <.input id="first-name" placeholder="Jordan" />
          </.field>
          <.field>
            <.field_label for="last-name">Last Name</.field_label>
            <.input id="last-name" placeholder="Lee" />
          </.field>
        </.field_group>
        """
      },
      %Variation{
        id: :field_group,
        description: "Stacked fields with action row",
        template: """
        <.field_group>
          <.field>
            <.field_label for="fieldgroup-name">Name</.field_label>
            <.input id="fieldgroup-name" placeholder="Jordan Lee" />
          </.field>
          <.field>
            <.field_label for="fieldgroup-email">Email</.field_label>
            <.input id="fieldgroup-email" type="email" placeholder="name@example.com" />
            <.field_description>We'll send updates to this address.</.field_description>
          </.field>
          <.field orientation="horizontal">
            <.button type="reset" variant="outline">Reset</.button>
            <.button type="submit">Submit</.button>
          </.field>
        </.field_group>
        """
      },
      %Variation{
        id: :form,
        description: "Full form with mixed inputs",
        template: """
        <form class="w-full max-w-sm">
          <.field_group>
            <.field>
              <.field_label for="form-name">Name</.field_label>
              <.input id="form-name" type="text" placeholder="Evil Rabbit" required />
            </.field>
            <.field>
              <.field_label for="form-email">Email</.field_label>
              <.input id="form-email" type="email" placeholder="john@example.com" />
              <.field_description>We'll never share your email with anyone.</.field_description>
            </.field>
            <div class="grid grid-cols-2 gap-4">
              <.field>
                <.field_label for="form-phone">Phone</.field_label>
                <.input id="form-phone" type="tel" placeholder="+1 (555) 123-4567" />
              </.field>
              <.field>
                <.field_label for="form-country">Country</.field_label>
                <.select id="form-country" value="us">
                  <.select_item value="us">United States</.select_item>
                  <.select_item value="uk">United Kingdom</.select_item>
                  <.select_item value="ca">Canada</.select_item>
                </.select>
              </.field>
            </div>
            <.field>
              <.field_label for="form-address">Address</.field_label>
              <.input id="form-address" type="text" placeholder="123 Main St" />
            </.field>
            <.field orientation="horizontal">
              <.button type="button" variant="outline">Cancel</.button>
              <.button type="submit">Submit</.button>
            </.field>
          </.field_group>
        </form>
        """
      }
    ]
  end
end

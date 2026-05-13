defmodule Shadcn.Storybook.Field do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Field

  def function, do: &Field.field/1

  def imports,
    do: [
      {Shadcn.Components.Field,
       [
         field_content: 1,
         field_description: 1,
         field_error: 1,
         field_group: 1,
         field_label: 1,
         field_legend: 1,
         field_separator: 1,
         field_set: 1,
         field_title: 1
       ]},
      {WatchClubWeb.UI.Button, [button: 1]},
      {Shadcn.Components.Checkbox, [checkbox: 1]},
      {Shadcn.Components.Input, [input: 1]},
      {Shadcn.Components.RadioGroup, [radio_group: 1]},
      {Shadcn.Components.Select, [select: 1, select_item: 1]}
    ]

  defp container_template(content) do
    """
    <div class="w-[480px] p-4">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :input,
        description: "Inputs with labels and descriptions",
        template: """
        <.field_set class="w-full max-w-xs">
          <.field_group>
            <.field>
              <.field_label for="username">Username</.field_label>
              <.input id="username" type="text" placeholder="Max Leiter" />
              <.field_description>Choose a unique username for your account.</.field_description>
            </.field>
            <.field>
              <.field_label for="password">Password</.field_label>
              <.field_description>Must be at least 8 characters long.</.field_description>
              <.input id="password" type="password" placeholder="••••••••" />
            </.field>
          </.field_group>
        </.field_set>
        """
      },
      %Variation{
        id: :select,
        description: "Select field",
        template: """
        <.field class="w-full max-w-xs">
          <.field_label for="department">Department</.field_label>
          <.select id="department" placeholder="Choose department">
            <.select_item value="engineering">Engineering</.select_item>
            <.select_item value="design">Design</.select_item>
            <.select_item value="marketing">Marketing</.select_item>
            <.select_item value="sales">Sales</.select_item>
            <.select_item value="support">Customer Support</.select_item>
            <.select_item value="hr">Human Resources</.select_item>
            <.select_item value="finance">Finance</.select_item>
            <.select_item value="operations">Operations</.select_item>
          </.select>
          <.field_description>Select your department or area of work.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :checkbox,
        description: "Checkbox group with separator and field content",
        template: """
        <.field_group class="w-full max-w-xs">
          <.field_set>
            <.field_legend variant="label">Show these items on the desktop</.field_legend>
            <.field_description>Select the items you want to show on the desktop.</.field_description>
            <.field_group class="gap-3">
              <.field orientation="horizontal">
                <.checkbox id="hard-disks" checked />
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
            </.field_group>
          </.field_set>
          <.field_separator />
          <.field orientation="horizontal">
            <.checkbox id="sync-folders" checked />
            <.field_content>
              <.field_label for="sync-folders">Sync Desktop & Documents folders</.field_label>
              <.field_description>
                Your Desktop & Documents folders are being synced with iCloud Drive. You can access them from other devices.
              </.field_description>
            </.field_content>
          </.field>
        </.field_group>
        """
      },
      %Variation{
        id: :radio,
        description: "Radio group with legend",
        template: """
        <.field_set class="w-full max-w-xs">
          <.field_legend variant="label">Subscription Plan</.field_legend>
          <.field_description>Yearly and lifetime plans offer significant savings.</.field_description>
          <.radio_group name="plan" value="monthly">
            <:item value="monthly">Monthly ($9.99/month)</:item>
            <:item value="yearly">Yearly ($99.99/year)</:item>
            <:item value="lifetime">Lifetime ($299.99)</:item>
          </.radio_group>
        </.field_set>
        """
      },
      %Variation{
        id: :choice_card,
        description: "Selectable cards via radio inside field label",
        template: """
        <.field_set class="w-full max-w-xs">
          <.field_legend variant="label">Compute Environment</.field_legend>
          <.field_description>Select the compute environment for your cluster.</.field_description>
          <div role="radiogroup" data-slot="radio-group">
            <.field_label for="env-kubernetes">
              <.field orientation="horizontal">
                <.field_content>
                  <.field_title>Kubernetes</.field_title>
                  <.field_description>Run GPU workloads on a K8s cluster.</.field_description>
                </.field_content>
                <span data-slot="radio-group-item" role="radio">
                  <input type="radio" name="env" value="kubernetes" id="env-kubernetes" checked data-slot="radio-group-input" />
                  <span data-slot="radio-group-indicator" aria-hidden="true">
                    <span data-slot="radio-group-dot" />
                  </span>
                </span>
              </.field>
            </.field_label>
            <.field_label for="env-vm">
              <.field orientation="horizontal">
                <.field_content>
                  <.field_title>Virtual Machine</.field_title>
                  <.field_description>Access a cluster to run GPU workloads.</.field_description>
                </.field_content>
                <span data-slot="radio-group-item" role="radio">
                  <input type="radio" name="env" value="vm" id="env-vm" data-slot="radio-group-input" />
                  <span data-slot="radio-group-indicator" aria-hidden="true">
                    <span data-slot="radio-group-dot" />
                  </span>
                </span>
              </.field>
            </.field_label>
          </div>
        </.field_set>
        """
      },
      %Variation{
        id: :fieldset,
        description: "Fieldset with grid layout",
        template: """
        <.field_set class="w-full max-w-sm">
          <.field_legend>Address Information</.field_legend>
          <.field_description>We need your address to deliver your order.</.field_description>
          <.field_group>
            <.field>
              <.field_label for="street">Street Address</.field_label>
              <.input id="street" type="text" placeholder="123 Main St" />
            </.field>
            <div class="grid grid-cols-2 gap-4">
              <.field>
                <.field_label for="city">City</.field_label>
                <.input id="city" type="text" placeholder="New York" />
              </.field>
              <.field>
                <.field_label for="zip">Postal Code</.field_label>
                <.input id="zip" type="text" placeholder="90502" />
              </.field>
            </div>
          </.field_group>
        </.field_set>
        """
      },
      %Variation{
        id: :field_group,
        description: "Grouped fieldsets separated",
        template: """
        <.field_group class="w-full max-w-xs">
          <.field_set>
            <.field_label>Responses</.field_label>
            <.field_description>
              Get notified when ChatGPT responds to requests that take time, like research or image generation.
            </.field_description>
            <.field_group data-slot="checkbox-group">
              <.field orientation="horizontal">
                <.checkbox id="resp-push" checked disabled />
                <.field_label for="resp-push" class="font-normal">Push notifications</.field_label>
              </.field>
            </.field_group>
          </.field_set>
          <.field_separator />
          <.field_set>
            <.field_label>Tasks</.field_label>
            <.field_description>
              Get notified when tasks you've created have updates. <a href="#">Manage tasks</a>
            </.field_description>
            <.field_group data-slot="checkbox-group">
              <.field orientation="horizontal">
                <.checkbox id="tasks-push" />
                <.field_label for="tasks-push" class="font-normal">Push notifications</.field_label>
              </.field>
              <.field orientation="horizontal">
                <.checkbox id="tasks-email" />
                <.field_label for="tasks-email" class="font-normal">Email notifications</.field_label>
              </.field>
            </.field_group>
          </.field_set>
        </.field_group>
        """
      },
      %Variation{
        id: :responsive,
        description: "Responsive orientation (label+description on the side at sm+)",
        template: """
        <form class="w-full max-w-lg">
          <.field_set>
            <.field_legend>Profile</.field_legend>
            <.field_description>Fill in your profile information.</.field_description>
            <.field_group>
              <.field orientation="responsive">
                <.field_content>
                  <.field_label for="name">Name</.field_label>
                  <.field_description>Provide your full name for identification.</.field_description>
                </.field_content>
                <.input id="name" placeholder="Evil Rabbit" required />
              </.field>
              <.field orientation="responsive">
                <.button type="submit">Submit</.button>
                <.button type="button" variant="outline">Cancel</.button>
              </.field>
            </.field_group>
          </.field_set>
        </form>
        """
      },
      %Variation{
        id: :error,
        description: "Field with validation error",
        template: """
        <.field invalid class="w-full max-w-xs">
          <.field_label for="username-err">Username</.field_label>
          <.input id="username-err" aria-invalid="true" value="x" />
          <.field_error errors={["Must be at least 3 characters"]} />
        </.field>
        """
      },
      %Variation{
        id: :separator,
        description: "Field separator with content",
        template: """
        <.field_group class="w-full max-w-xs">
          <.field>
            <.field_label for="username2">Username</.field_label>
            <.input id="username2" />
          </.field>
          <.field_separator>OR</.field_separator>
          <.field>
            <.field_label for="email2">Email</.field_label>
            <.input id="email2" type="email" />
          </.field>
        </.field_group>
        """
      }
    ]
  end
end

defmodule Shadcn.Storybook.InputOtp do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.InputOtp

  def function, do: &InputOtp.input_otp/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.Card, [card: 1]},
      {Shadcn.Components.Field, [field: 1, field_description: 1, field_label: 1]},
      {Lucideicons, [refresh_cw: 1]}
    ]

  defp container_template(content) do
    """
    <div class="flex w-full max-w-md p-6">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :demo,
        description: "Six-digit one-time-password input",
        attributes: %{id: "otp-demo", name: "code", length: 6, value: "123456"}
      },
      %Variation{
        id: :separator,
        description: "Three groups of two digits separated by dashes",
        attributes: %{
          id: "otp-separator",
          name: "code-sep",
          length: 6,
          groups: [2, 2, 2]
        }
      },
      %Variation{
        id: :disabled,
        description: "Disabled state, pre-filled",
        attributes: %{
          id: "otp-disabled",
          name: "code-disabled",
          length: 6,
          groups: [3, 3],
          value: "123456",
          disabled: true
        }
      },
      %Variation{
        id: :invalid,
        description: "aria-invalid driven by errors",
        attributes: %{
          id: "otp-invalid",
          name: "code-invalid",
          length: 6,
          groups: [2, 2, 2],
          value: "000000",
          errors: ["Code is invalid"]
        }
      },
      %Variation{
        id: :four_digits,
        description: "Four-digit code",
        attributes: %{id: "otp-four", name: "code-four", length: 4}
      },
      %Variation{
        id: :alphanumeric,
        description: "Letters and digits accepted",
        attributes: %{
          id: "otp-alpha",
          name: "code-alpha",
          length: 6,
          groups: [3, 3],
          pattern: "[A-Za-z0-9]*"
        }
      },
      %Variation{
        id: :form,
        description: "Verification form inside a card",
        template: """
        <.card class="mx-auto w-full max-w-md">
          <:title>Verify your login</:title>
          <:description>
            Enter the verification code we sent to your email address: <span class="font-medium">m@example.com</span>.
          </:description>
          <.field>
            <div class="flex items-center justify-between">
              <.field_label for="otp-verification">Verification code</.field_label>
              <.button variant="outline" size="xs">
                <:icon position="start"><Lucideicons.refresh_cw /></:icon>
                Resend Code
              </.button>
            </div>
            <.input_otp id="otp-verification" name="verification" length={6} groups={[3, 3]} required />
            <.field_description>
              <a href="#">I no longer have access to this email address.</a>
            </.field_description>
          </.field>
          <:footer>
            <.field>
              <.button type="submit" class="w-full">Verify</.button>
              <div class="text-sm text-muted-foreground">
                Having trouble signing in? <a href="#" class="underline underline-offset-4 transition-colors hover:text-primary">Contact support</a>
              </div>
            </.field>
          </:footer>
        </.card>
        """
      }
    ]
  end
end

defmodule Shadcn.Storybook.Accordion do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Accordion

  def function, do: &Accordion.accordion/1

  def imports, do: [{Shadcn.Components.Card, [card: 1]}]

  def variations do
    [
      %Variation{
        id: :basic,
        description: "Basic — single, first item open by default",
        attributes: %{type: "single", class: "max-w-lg"},
        slots: [
          ~s|<:item id="item-1" trigger="How do I reset my password?" open>Click on 'Forgot Password' on the login page, enter your email address, and we'll send you a link to reset your password. The link will expire in 24 hours.</:item>|,
          ~s|<:item id="item-2" trigger="Can I change my subscription plan?">Yes, you can upgrade or downgrade your plan at any time from your account settings. Changes will be reflected in your next billing cycle.</:item>|,
          ~s|<:item id="item-3" trigger="What payment methods do you accept?">We accept all major credit cards, PayPal, and bank transfers. All payments are processed securely through our payment partners.</:item>|
        ]
      },
      %Variation{
        id: :multiple,
        description: "Multiple items open at once",
        attributes: %{type: "multiple", class: "max-w-lg"},
        slots: [
          ~s|<:item id="notifications" trigger="Notification Settings" open>Manage how you receive notifications. You can enable email alerts for updates or push notifications for mobile devices.</:item>|,
          ~s|<:item id="privacy" trigger="Privacy & Security">Control your privacy settings and security preferences. Enable two-factor authentication, manage connected devices, review active sessions, and configure data sharing preferences. You can also download your data or delete your account.</:item>|,
          ~s|<:item id="billing" trigger="Billing & Subscription">View your current plan, payment history, and upcoming invoices. Update your payment method, change your subscription tier, or cancel your subscription.</:item>|
        ]
      },
      %Variation{
        id: :disabled,
        description: "With a disabled item",
        attributes: %{type: "single", class: "max-w-lg"},
        slots: [
          ~s|<:item id="item-1" trigger="Can I access my account history?">Yes, you can view your complete account history including all transactions, plan changes, and support tickets in the Account History section of your dashboard.</:item>|,
          ~s|<:item id="item-2" trigger="Premium feature information" disabled>This section contains information about premium features. Upgrade your plan to access this content.</:item>|,
          ~s|<:item id="item-3" trigger="How do I update my email address?">You can update your email address in your account settings. You'll receive a verification email at your new address to confirm the change.</:item>|
        ]
      },
      %Variation{
        id: :borders,
        description: "Borders — wrapped in a rounded border, item dividers",
        attributes: %{
          type: "single",
          class: "max-w-lg rounded-lg border"
        },
        slots: [
          ~s|<:item id="billing" class="border-b px-4 last:border-b-0" trigger="How does billing work?" open>We offer monthly and annual subscription plans. Billing is charged at the beginning of each cycle, and you can cancel anytime. All plans include automatic backups, 24/7 support, and unlimited team members.</:item>|,
          ~s|<:item id="security" class="border-b px-4 last:border-b-0" trigger="Is my data secure?">Yes. We use end-to-end encryption, SOC 2 Type II compliance, and regular third-party security audits. All data is encrypted at rest and in transit using industry-standard protocols.</:item>|,
          ~s|<:item id="integration" class="border-b px-4 last:border-b-0" trigger="What integrations do you support?">We integrate with 500+ popular tools including Slack, Zapier, Salesforce, HubSpot, and more. You can also build custom integrations using our REST API and webhooks.</:item>|
        ]
      },
      %Variation{
        id: :card,
        description: "Wrapped in a Card",
        template: """
        <.card class="w-full max-w-sm">
          <:title>Subscription & Billing</:title>
          <:description>Common questions about your account, plans, payments and cancellations.</:description>
          <.psb-variation/>
        </.card>
        """,
        attributes: %{type: "single"},
        slots: [
          ~s|<:item id="plans" trigger="What subscription plans do you offer?" open>We offer three subscription tiers: Starter ($9/month), Professional ($29/month), and Enterprise ($99/month). Each plan includes increasing storage limits, API access, priority support, and team collaboration features.</:item>|,
          ~s|<:item id="billing" trigger="How does billing work?">Billing occurs automatically at the start of each billing cycle. We accept all major credit cards, PayPal, and ACH transfers for enterprise customers. You'll receive an invoice via email after each payment.</:item>|,
          ~s|<:item id="cancel" trigger="How do I cancel my subscription?">You can cancel your subscription anytime from your account settings. There are no cancellation fees or penalties. Your access will continue until the end of your current billing period.</:item>|
        ]
      }
    ]
  end
end

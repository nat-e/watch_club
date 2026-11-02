defmodule WatchClub.MediaSources.Servarr.WizardTest do
  # Stubbing the Servarr API changes global config.
  use WatchClub.DataCase, async: false

  import WatchClub.MediaSources

  alias Ash.Error.Changes.InvalidAttribute
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Servarr.Wizard

  setup do
    previous = Application.get_env(:watch_club, :servarr_req_options)
    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
  end

  defp stub_servarr(plug) do
    Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client})
    Req.Test.stub(Client, plug)
  end

  describe "create_servarr_wizard_for_edit/*" do
    test "opens the connection step with the saved values, without calling the server" do
      admin = generate(administrator())

      source =
        generate(radarr_media_source(actor: admin, base_url: "http://radarr:7878"))
        |> Ash.load!(:implementation, authorize?: false)

      # A server that is down or moved must not prevent editing its source.
      stub_servarr(&Req.Test.transport_error(&1, :econnrefused))

      assert %Wizard{step: :connection, base_url: "http://radarr:7878", api_key: "securekey"} =
               create_servarr_wizard_for_edit!(source)
    end
  end

  describe "configure_servarr_connection/*" do
    test "checks the server and loads its quality profiles and root folders" do
      wizard = generate(servarr_wizard())

      assert %Wizard{
               step: :request_profile,
               base_url: "http://radarr:7878",
               quality_profiles: [_ | _],
               root_folders: [_ | _]
             } =
               configure_servarr_connection!(wizard, %{
                 base_url: " radarr:7878/ ",
                 api_key: "securekey"
               })
    end

    test "rejects an invalid URL" do
      wizard = generate(servarr_wizard())

      configure_servarr_connection(wizard, %{base_url: "http://radarr 7878", api_key: "securekey"})
      |> assert_has_error(Ash.Error.Invalid, fn
        %InvalidAttribute{field: :base_url, message: "This URL is not valid."} -> true
        _ -> false
      end)
    end

    test "rejects a server that can't be reached" do
      stub_servarr(&Req.Test.transport_error(&1, :econnrefused))
      wizard = generate(servarr_wizard())

      configure_servarr_connection(wizard, %{base_url: "http://radarr:7878", api_key: "securekey"})
      |> assert_has_error(Ash.Error.Invalid, fn
        %InvalidAttribute{field: :base_url, message: "Could not connect to %{name} at this URL."} ->
          true

        _ ->
          false
      end)
    end

    test "rejects a URL that answers with a web page" do
      stub_servarr(&Req.Test.html(&1, "<html></html>"))
      wizard = generate(servarr_wizard())

      configure_servarr_connection(wizard, %{base_url: "http://radarr:7878", api_key: "securekey"})
      |> assert_has_error(Ash.Error.Invalid, fn
        %InvalidAttribute{
          field: :base_url,
          message: "This URL did not respond like a %{name} server."
        } ->
          true

        _ ->
          false
      end)
    end
  end

  describe "configure_servarr_webhook/*" do
    test "checks that the server can reach the callback URL" do
      wizard = generate(servarr_wizard(step: :webhook))

      assert %Wizard{step: :finished, webhook_callback_base_url: "http://watch_club:4000"} =
               configure_servarr_webhook!(wizard, %{webhook_callback_base_url: "watch_club:4000/"})
    end

    test "rejects an invalid callback URL" do
      wizard = generate(servarr_wizard(step: :webhook))

      configure_servarr_webhook(wizard, %{webhook_callback_base_url: "http://watch club"})
      |> assert_has_error(Ash.Error.Invalid, fn
        %InvalidAttribute{field: :webhook_callback_base_url, message: "This URL is not valid."} ->
          true

        _ ->
          false
      end)
    end

    test "rejects a callback URL the server can't reach" do
      # Servarr answers 500 when it can't reach the callback URL.
      stub_servarr(fn conn ->
        conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"message" => "Connection refused"})
      end)

      wizard = generate(servarr_wizard(step: :webhook))

      configure_servarr_webhook(wizard, %{webhook_callback_base_url: "http://watch_club:4000"})
      |> assert_has_error(Ash.Error.Invalid, fn
        %InvalidAttribute{
          field: :webhook_callback_base_url,
          message: "%{name} could not reach this URL."
        } ->
          true

        _ ->
          false
      end)
    end

    test "rejects a callback URL that never answers" do
      # The server keeps waiting on the callback URL, so the test times out.
      stub_servarr(&Req.Test.transport_error(&1, :timeout))
      wizard = generate(servarr_wizard(step: :webhook))

      configure_servarr_webhook(wizard, %{webhook_callback_base_url: "http://watch_club:4000"})
      |> assert_has_error(Ash.Error.Invalid, fn
        %InvalidAttribute{
          field: :webhook_callback_base_url,
          message: "%{name} could not reach this URL."
        } ->
          true

        _ ->
          false
      end)
    end

    test "rejects a server that can't be reached" do
      stub_servarr(&Req.Test.transport_error(&1, :econnrefused))
      wizard = generate(servarr_wizard(step: :webhook))

      configure_servarr_webhook(wizard, %{webhook_callback_base_url: "http://watch_club:4000"})
      |> assert_has_error(Ash.Error.Invalid, fn
        %InvalidAttribute{
          field: :webhook_callback_base_url,
          message: "Could not connect to %{name}."
        } ->
          true

        _ ->
          false
      end)
    end
  end
end

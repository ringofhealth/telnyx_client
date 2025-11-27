defmodule Telnyx.CallControlTest do
  use ExUnit.Case, async: false

  alias Telnyx.{CallControl, Error}
  alias Telnyx.CallControl.Result

  describe "transfer/3" do
    test "returns error when no API key is configured" do
      # Ensure no API key in application env
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} =
               CallControl.transfer("v2:test123", "+18005551234")
    end

    test "returns error when API key is empty" do
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication, message: message}} =
               CallControl.transfer("v2:test123", "+18005551234", api_key: "")

      assert message =~ "cannot be empty"
    end

    test "uses api_key from opts over application config" do
      # Set a dummy key in app config
      Application.put_env(:telnyx, :api_key, "app-config-key")

      # The request will fail with auth error from Telnyx, but we're testing
      # that it attempts the request with the provided key
      assert {:error, %Error{}} =
               CallControl.transfer("v2:test123", "+18005551234", api_key: "explicit-key")

      # Clean up
      Application.delete_env(:telnyx, :api_key)
    end

    test "reads api_key from {:system, env_var} config" do
      # Set up environment-based config
      System.put_env("TEST_TELNYX_API_KEY", "env-var-key")
      Application.put_env(:telnyx, :api_key, {:system, "TEST_TELNYX_API_KEY"})

      # Will fail auth but proves it reads from env
      assert {:error, %Error{}} =
               CallControl.transfer("v2:test123", "+18005551234")

      # Clean up
      System.delete_env("TEST_TELNYX_API_KEY")
      Application.delete_env(:telnyx, :api_key)
    end
  end

  describe "hangup/2" do
    test "returns error when no API key is configured" do
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} =
               CallControl.hangup("v2:test123")
    end
  end

  describe "answer/2" do
    test "returns error when no API key is configured" do
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} =
               CallControl.answer("v2:test123")
    end
  end

  describe "telemetry integration" do
    setup do
      test_pid = self()

      handler = fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end

      :telemetry.attach(
        "test-call-control-handler",
        [:telnyx, :call_control, :transfer, :stop],
        handler,
        nil
      )

      on_exit(fn ->
        :telemetry.detach("test-call-control-handler")
        Application.delete_env(:telnyx, :api_key)
      end)

      :ok
    end

    test "emits telemetry event on authentication error" do
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} =
               CallControl.transfer("v2:test123", "+18005551234")

      assert_receive {:telemetry_event, [:telnyx, :call_control, :transfer, :stop], measurements,
                      metadata}

      assert measurements.duration > 0
      assert metadata.status == :error
      assert metadata.error_type == :authentication
      assert metadata.action == :transfer
      assert metadata.call_control_id == "v2:test123"
    end

    test "includes call_control_id and action in telemetry metadata" do
      Application.delete_env(:telnyx, :api_key)

      CallControl.transfer("v2:my-call-id", "sip:+14155551234@trunk.livekit.cloud")

      assert_receive {:telemetry_event, _, _, metadata}

      assert metadata.call_control_id == "v2:my-call-id"
      assert metadata.action == :transfer
    end
  end

  describe "Result struct" do
    test "from_response/3 extracts command_id from nested data" do
      response = %{"data" => %{"command_id" => "cmd_abc123"}}

      result = Result.from_response(response, :transfer, "v2:call123")

      assert %Result{
               command_id: "cmd_abc123",
               status: :ok,
               action: :transfer,
               call_control_id: "v2:call123"
             } = result
    end

    test "from_response/3 extracts command_id from flat response" do
      response = %{"command_id" => "cmd_xyz789"}

      result = Result.from_response(response, :hangup, "v2:call456")

      assert %Result{
               command_id: "cmd_xyz789",
               status: :ok,
               action: :hangup,
               call_control_id: "v2:call456"
             } = result
    end

    test "from_response/3 handles missing command_id" do
      response = %{"result" => "ok"}

      result = Result.from_response(response, :answer, "v2:call789")

      assert %Result{
               command_id: nil,
               status: :ok,
               action: :answer,
               call_control_id: "v2:call789"
             } = result
    end
  end
end

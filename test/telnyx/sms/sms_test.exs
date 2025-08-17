defmodule Telnyx.SMSTest do
  use ExUnit.Case, async: true

  alias Telnyx.{SMS, Config, Error}

  describe "send/2" do
    test "returns error when no config provided and no default config" do
      Application.delete_env(:telnyx, :default_messaging_profile_id)

      message = %{to: "+19876543210", text: "Hello!"}

      assert {:error, %Error{type: :validation}} = SMS.send(message)
    end

    test "returns error for invalid message params" do
      config = Config.new(messaging_profile_id: "test-profile")

      # Missing required field
      assert {:error, %Error{type: :validation}} = SMS.send(%{to: "+19876543210"}, config)

      # Empty field
      assert {:error, %Error{type: :validation}} = SMS.send(%{to: "", text: "Hello!"}, config)

      # Wrong type
      assert {:error, %Error{type: :validation}} = SMS.send("not a map", config)
    end

    test "returns error when no API key is configured" do
      config = Config.new(messaging_profile_id: "test-profile")
      message = %{to: "+19876543210", text: "Hello!"}

      # Ensure no API key in config or application env
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} = SMS.send(message, config)
    end

    test "returns error when neither 'from' nor messaging_profile_id is provided" do
      config = Config.new(messaging_profile_id: "test-profile", api_key: "test-key")

      # Create message without 'from' and then remove messaging_profile_id
      message = %{to: "+19876543210", text: "Hello!", messaging_profile_id: nil}

      # Override config to have no messaging_profile_id
      invalid_config = %{config | messaging_profile_id: nil}

      assert {:error, %Error{type: :validation, message: message}} =
               SMS.send(message, invalid_config)

      assert message =~ "Either 'from' phone number or 'messaging_profile_id' must be provided"
    end
  end

  describe "send_without_telemetry/2" do
    test "bypasses telemetry events" do
      config = Config.new(messaging_profile_id: "test-profile", api_key: "test-key")
      message = %{to: "+19876543210", text: "Hello!"}

      # This should not emit telemetry events and will return an authentication error
      # when hitting the real API with a fake key (which is expected behavior)
      assert {:error, %Error{type: :authentication}} = SMS.send_without_telemetry(message, config)
    end
  end

  describe "telemetry integration" do
    setup do
      # Attach a test telemetry handler
      test_pid = self()

      handler = fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end

      :telemetry.attach(
        "test-telnyx-handler",
        [:telnyx, :sms, :send, :stop],
        handler,
        nil
      )

      config = Config.new(messaging_profile_id: "test-profile", api_key: "test-key")

      on_exit(fn ->
        :telemetry.detach("test-telnyx-handler")
      end)

      {:ok, config: config}
    end

    test "emits telemetry event on validation error", %{config: config} do
      message = %{to: "", text: "Hello!"}

      assert {:error, %Error{type: :validation}} = SMS.send(message, config)

      assert_receive {:telemetry_event, [:telnyx, :sms, :send, :stop], measurements, metadata}

      assert measurements.duration > 0
      assert metadata.status == :error
      assert metadata.error_type == :validation
      assert metadata.to == ""
      assert metadata.messaging_profile_id == "test-profile"
    end

    test "emits telemetry event on authentication error", %{config: config} do
      # Remove API key to trigger auth error
      config_no_key = %{config | api_key: nil}
      Application.delete_env(:telnyx, :api_key)

      message = %{to: "+19876543210", text: "Hello!"}

      assert {:error, %Error{type: :authentication}} = SMS.send(message, config_no_key)

      assert_receive {:telemetry_event, [:telnyx, :sms, :send, :stop], measurements, metadata}

      assert measurements.duration > 0
      assert metadata.status == :error
      assert metadata.error_type == :authentication
      assert metadata.to == "+19876543210"
    end
  end
end
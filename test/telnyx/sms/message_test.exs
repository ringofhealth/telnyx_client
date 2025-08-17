defmodule Telnyx.SMS.MessageTest do
  use ExUnit.Case, async: true

  alias Telnyx.SMS.Message
  alias Telnyx.{Config, Error}

  describe "new/1" do
    test "creates message with required fields" do
      params = %{to: "+19876543210", text: "Hello!"}

      assert {:ok, message} = Message.new(params)
      assert message.to == "+19876543210"
      assert message.text == "Hello!"
      assert message.from == nil
      assert message.messaging_profile_id == nil
      assert message.type == "SMS"
    end

    test "creates message with all fields" do
      params = %{
        to: "+19876543210",
        text: "Hello!",
        from: "+14165551234",
        messaging_profile_id: "test-profile",
        webhook_url: "https://example.com/webhook",
        webhook_failover_url: "https://example.com/failover",
        use_profile_webhooks: true,
        type: "SMS"
      }

      assert {:ok, message} = Message.new(params)
      assert message.to == "+19876543210"
      assert message.text == "Hello!"
      assert message.from == "+14165551234"
      assert message.messaging_profile_id == "test-profile"
      assert message.webhook_url == "https://example.com/webhook"
      assert message.webhook_failover_url == "https://example.com/failover"
      assert message.use_profile_webhooks == true
      assert message.type == "SMS"
    end

    test "accepts string keys" do
      params = %{"to" => "+19876543210", "text" => "Hello!"}

      assert {:ok, message} = Message.new(params)
      assert message.to == "+19876543210"
      assert message.text == "Hello!"
    end

    test "returns error when 'to' is missing" do
      params = %{text: "Hello!"}

      assert {:error, %Error{type: :validation, message: "Field 'to' is required"}} =
               Message.new(params)
    end

    test "returns error when 'text' is missing" do
      params = %{to: "+19876543210"}

      assert {:error, %Error{type: :validation, message: "Field 'text' is required"}} =
               Message.new(params)
    end

    test "returns error when 'to' is empty" do
      params = %{to: "", text: "Hello!"}

      assert {:error, %Error{type: :validation, message: "Field 'to' cannot be empty"}} =
               Message.new(params)
    end

    test "returns error when 'text' is empty" do
      params = %{to: "+19876543210", text: ""}

      assert {:error, %Error{type: :validation, message: "Field 'text' cannot be empty"}} =
               Message.new(params)
    end

    test "returns error when 'to' is not a string" do
      params = %{to: 19876543210, text: "Hello!"}

      assert {:error, %Error{type: :validation, message: "Field 'to' must be a string"}} =
               Message.new(params)
    end

    test "returns error when 'text' is not a string" do
      params = %{to: "+19876543210", text: 123}

      assert {:error, %Error{type: :validation, message: "Field 'text' must be a string"}} =
               Message.new(params)
    end

    test "returns error when params is not a map" do
      assert {:error, %Error{type: :validation, message: "Message must be a map"}} =
               Message.new("not a map")
    end
  end

  describe "to_api_params/1" do
    test "converts message to API parameters map" do
      {:ok, message} =
        Message.new(%{
          to: "+19876543210",
          text: "Hello!",
          from: "+14165551234",
          messaging_profile_id: "test-profile"
        })

      params = Message.to_api_params(message)

      assert params == %{
               to: "+19876543210",
               text: "Hello!",
               from: "+14165551234",
               messaging_profile_id: "test-profile",
               type: "SMS"
             }
    end

    test "excludes nil values from API parameters" do
      {:ok, message} = Message.new(%{to: "+19876543210", text: "Hello!"})

      params = Message.to_api_params(message)

      assert params == %{
               to: "+19876543210",
               text: "Hello!",
               type: "SMS"
             }

      refute Map.has_key?(params, :from)
      refute Map.has_key?(params, :messaging_profile_id)
    end
  end

  describe "merge_with_config/2" do
    test "merges message with config defaults" do
      {:ok, message} = Message.new(%{to: "+19876543210", text: "Hello!"})

      config =
        Config.new(
          messaging_profile_id: "config-profile",
          default_from: "+14165551234",
          webhook_url: "https://config.com/webhook"
        )

      merged = Message.merge_with_config(message, config)

      assert merged.to == "+19876543210"
      assert merged.text == "Hello!"
      assert merged.from == "+14165551234"
      assert merged.messaging_profile_id == "config-profile"
      assert merged.webhook_url == "https://config.com/webhook"
    end

    test "message values override config defaults" do
      {:ok, message} =
        Message.new(%{
          to: "+19876543210",
          text: "Hello!",
          from: "+15555551234",
          messaging_profile_id: "message-profile"
        })

      config =
        Config.new(
          messaging_profile_id: "config-profile",
          default_from: "+14165551234"
        )

      merged = Message.merge_with_config(message, config)

      assert merged.from == "+15555551234"
      assert merged.messaging_profile_id == "message-profile"
    end

    test "preserves message values when config has nil values" do
      {:ok, message} =
        Message.new(%{
          to: "+19876543210",
          text: "Hello!",
          webhook_url: "https://message.com/webhook"
        })

      config = Config.new(messaging_profile_id: "config-profile")

      merged = Message.merge_with_config(message, config)

      assert merged.webhook_url == "https://message.com/webhook"
      assert merged.messaging_profile_id == "config-profile"
    end
  end
end
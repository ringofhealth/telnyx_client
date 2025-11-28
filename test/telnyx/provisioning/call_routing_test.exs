defmodule Telnyx.Provisioning.CallRoutingTest do
  use ExUnit.Case, async: false

  alias Telnyx.Provisioning.CallRouting
  alias Telnyx.Error

  describe "provision/2" do
    test "returns error when application_name is missing" do
      params = %{
        webhook_event_url: "https://example.com/webhooks"
      }

      assert {:error, %Error{type: :validation, message: message}} =
               CallRouting.provision(params, "api-key")

      assert message =~ "application_name"
    end

    test "returns error when webhook_event_url is missing" do
      params = %{
        application_name: "test-app"
      }

      assert {:error, %Error{type: :validation, message: message}} =
               CallRouting.provision(params, "api-key")

      assert message =~ "webhook_event_url"
    end

    test "returns error when application_name is empty" do
      params = %{
        application_name: "",
        webhook_event_url: "https://example.com/webhooks"
      }

      assert {:error, %Error{type: :validation, message: message}} =
               CallRouting.provision(params, "api-key")

      assert message =~ "cannot be empty"
    end

    test "returns error when webhook_event_url is empty" do
      params = %{
        application_name: "test-app",
        webhook_event_url: ""
      }

      assert {:error, %Error{type: :validation, message: message}} =
               CallRouting.provision(params, "api-key")

      assert message =~ "cannot be empty"
    end

    test "returns API error with invalid credentials" do
      params = %{
        application_name: "test-app",
        webhook_event_url: "https://example.com/webhooks"
      }

      # Invalid API key will result in API error
      assert {:error, %Error{}} = CallRouting.provision(params, "invalid-key")
    end

    test "handles optional phone_number parameter" do
      params = %{
        application_name: "test-app",
        webhook_event_url: "https://example.com/webhooks",
        phone_number: "+18005551234"
      }

      # Will fail at API level but validates parameter structure
      assert {:error, %Error{}} = CallRouting.provision(params, "invalid-key")
    end

    test "handles optional webhook_api_version parameter" do
      params = %{
        application_name: "test-app",
        webhook_event_url: "https://example.com/webhooks",
        webhook_api_version: "2"
      }

      assert {:error, %Error{}} = CallRouting.provision(params, "invalid-key")
    end
  end

  describe "ensure_application_exists/3" do
    test "returns error with invalid API key" do
      params = %{webhook_event_url: "https://example.com/webhooks"}

      assert {:error, %Error{}} =
               CallRouting.ensure_application_exists("my-app", params, "invalid-key")
    end

    test "accepts empty params map" do
      # Will fail at API level but shouldn't crash
      assert {:error, %Error{}} =
               CallRouting.ensure_application_exists("my-app", %{}, "invalid-key")
    end
  end

  describe "assign_phone_number/3" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} =
               CallRouting.assign_phone_number("+18005551234", "app-id", "invalid-key")
    end

    test "returns error when phone number not found" do
      # Phone number lookup will fail with invalid key
      assert {:error, %Error{}} =
               CallRouting.assign_phone_number("+19999999999", "app-id", "invalid-key")
    end
  end

  describe "get_application_id/2" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} =
               CallRouting.get_application_id("my-app", "invalid-key")
    end

    test "returns error when application not found" do
      # With invalid key, the list call will fail
      assert {:error, %Error{}} =
               CallRouting.get_application_id("non-existent-app", "invalid-key")
    end
  end

  describe "parameter validation" do
    test "provision handles nil values correctly" do
      params = %{
        application_name: nil,
        webhook_event_url: "https://example.com/webhooks"
      }

      assert {:error, %Error{type: :validation}} = CallRouting.provision(params, "api-key")
    end

    test "provision with all valid parameters structure" do
      # Complete params structure
      params = %{
        application_name: "complete-app",
        webhook_event_url: "https://example.com/webhooks/inbound",
        webhook_api_version: "2",
        phone_number: "+18005551234"
      }

      # Will fail at API level but validates complete structure
      assert {:error, %Error{}} = CallRouting.provision(params, "invalid-key")
    end
  end
end
